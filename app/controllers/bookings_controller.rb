class BookingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_booking, only: %i[ show confirm decline cancel pay ]

  # GET /bookings or /bookings.json
  # The guest's own trips and the requests for locations they host.
  def index
    authorize Booking
    bookings = policy_scope(Booking).includes(:guest, :service, :resource, location: [ :host, :resources ]).chronological
    @bookings = bookings
    @trips = bookings.where(guest_id: current_user.id)
    # Hosts don't see a request until its deposit is paid.
    @requests = bookings.where(locations: { host_id: current_user.id }).where.not(payment_status: "awaiting")

    # Grouped for the page: what needs the host's reply, what's coming up,
    # and everything finished, declined or cancelled.
    now = Time.current
    requests = @requests.to_a
    trips = @trips.to_a
    @awaiting_reply = requests.select(&:respondable?)
    @upcoming_hosting = requests.select { |b| b.confirmed? && b.ended_at.present? && b.ended_at > now }
    @upcoming_trips = trips.select { |b| b.active? && b.ended_at.present? && b.ended_at > now }
    @past = (requests + trips - @awaiting_reply - @upcoming_hosting - @upcoming_trips)
      .uniq.sort_by { |b| b.started_at || Time.at(0) }.reverse
  end

  # GET /bookings/1 or /bookings/1.json
  # Coming back from Stripe Checkout (?paid=1), ask Stripe whether the
  # deposit went through, in case its webhook hasn't arrived yet.
  def show
    authorize @booking
    return unless params[:paid].present? && @booking.deposit_awaiting? && @booking.guest_id == current_user.id

    begin
      Deposits.sync!(@booking)
    rescue StripeApi::Error => e
      Rails.logger.warn("Deposit sync failed for booking #{@booking.id}: #{e.message}")
    end
  end

  # GET /bookings/new?location_id=1
  # Booking happens on the location page, by picking slots in the day view.
  def new
    location = Location.find_by(id: params[:location_id])
    return redirect_to(locations_path, alert: "Choose a location to book.") unless location

    redirect_to location_path(location, anchor: "availability")
  end

  # POST /bookings or /bookings.json
  def create
    location = Location.find_by(id: booking_params[:location_id])
    @booking = Booking.new(
      started_at: booking_params[:started_at],
      ended_at: booking_params[:ended_at],
      location: location,
      guest: current_user
    )
    # Only services and resources from this location can be picked; the
    # model double-checks too.
    if location
      @booking.service = location.services.find_by(id: booking_params[:service_id]) if booking_params[:service_id].present?
      @booking.resource = location.resources.find_by(id: booking_params[:resource_id]) if booking_params[:resource_id].present?
    end
    authorize @booking

    # Lock the location row so two simultaneous requests can't both pass the
    # overlap check and double-book the same time.
    saved = location.with_lock { @booking.save }

    # A deposit is due: send the guest to Stripe to pay it.
    return start_deposit_checkout(location) if saved && @booking.deposit_awaiting? && request.format.html?

    respond_to do |format|
      if saved
        format.html { redirect_to @booking, notice: "Booking requested. The host will confirm or decline it." }
        format.json { render :show, status: :created, location: @booking }
      else
        format.html do
          redirect_to location_path(location, start_date: @booking.started_at&.to_date, date: @booking.started_at&.to_date,
                                              resource_id: booking_params[:resource_id].presence, anchor: "availability"),
                      alert: "That time couldn't be booked: #{@booking.errors.full_messages.to_sentence}"
        end
        format.json { render json: @booking.errors, status: :unprocessable_entity }
      end
    end
  end

  # POST /bookings/1/pay
  # Goes back to the Stripe page for a deposit the guest hasn't paid yet.
  def pay
    authorize @booking
    session = StripeApi.get("/v1/checkout/sessions/#{@booking.stripe_checkout_session_id}")
    if session["status"] == "open" && session["url"].present?
      redirect_to session["url"], allow_other_host: true, status: :see_other
    else
      Deposits.record_session!(@booking, session)
      redirect_to @booking, alert: "That payment page has closed. Please pick a time again.", status: :see_other
    end
  rescue StripeApi::Error => e
    redirect_to @booking, alert: "Couldn't open the payment page: #{e.message}", status: :see_other
  end

  # PATCH /bookings/1/confirm
  def confirm
    authorize @booking
    change_status(notice: "Booking confirmed.") { @booking.location.with_lock { @booking.confirm! } }
  end

  # PATCH /bookings/1/decline
  # A paid deposit is refunded in full.
  def decline
    authorize @booking
    change_status(notice: "Booking declined.") do
      @booking.decline!
      refund_deposit
    end
  end

  # PATCH /bookings/1/cancel
  # Hosts who cancel always refund. Guests are refunded if they cancel at
  # least 24 hours ahead.
  def cancel
    authorize @booking
    by_host = @booking.location.host_id == current_user.id
    change_status(notice: "Booking cancelled.") do
      @booking.cancel!
      Deposits.close_checkout!(@booking)
      if @booking.deposit_paid?
        if Deposits.refund_on_cancel?(@booking, by_host: by_host)
          refund_deposit
        else
          @payment_note = " The #{@booking.deposit_label} deposit isn't refunded for cancellations within 24 hours."
        end
      end
    end
  end

  private

  def set_booking
    @booking = Booking.find(params.expect(:id))
  end

  def booking_params
    params.expect(booking: [ :started_at, :ended_at, :location_id, :service_id, :resource_id ])
  end

  def start_deposit_checkout(location)
    url = Deposits.start_checkout!(@booking, success_url: booking_url(@booking, paid: 1), cancel_url: booking_url(@booking))
    redirect_to url, allow_other_host: true, status: :see_other
  rescue StripeApi::Error => e
    Rails.logger.warn("Deposit checkout failed for booking #{@booking.id}: #{e.message}")
    @booking.update!(status: :cancelled, payment_status: :expired)
    redirect_to location_path(location, anchor: "availability"),
                alert: "The deposit payment couldn't start, so the time wasn't held. You haven't been charged. Please try again."
  end

  def refund_deposit
    return unless @booking.deposit_paid?

    Deposits.refund!(@booking)
    @payment_note = " The #{@booking.deposit_label} deposit was refunded."
  rescue StripeApi::Error => e
    Rails.logger.warn("Refund failed for booking #{@booking.id}: #{e.message}")
    @payment_note = " The deposit couldn't be refunded automatically (#{e.message}). Refund it from the Stripe dashboard."
  end

  def change_status(notice:)
    yield
    redirect_to @booking, notice: "#{notice}#{@payment_note}", status: :see_other
  rescue ActiveRecord::RecordInvalid, Booking::InvalidTransition => e
    redirect_to @booking, alert: e.message, status: :see_other
  end
end
