class BookingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_booking, only: %i[ show confirm decline cancel ]

  # GET /bookings or /bookings.json
  # The guest's own trips and the requests for locations they host.
  def index
    authorize Booking
    bookings = policy_scope(Booking).includes(:guest, location: :host).chronological
    @bookings = bookings
    @trips = bookings.where(guest_id: current_user.id)
    @requests = bookings.where(locations: { host_id: current_user.id })

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
  def show
    authorize @booking
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
    authorize @booking

    # Lock the location row so two simultaneous requests can't both pass the
    # overlap check and double-book the same time.
    saved = location.with_lock { @booking.save }

    respond_to do |format|
      if saved
        format.html { redirect_to @booking, notice: "Booking requested. The host will confirm or decline it." }
        format.json { render :show, status: :created, location: @booking }
      else
        format.html do
          redirect_to location_path(location, start_date: @booking.started_at&.to_date, date: @booking.started_at&.to_date, anchor: "availability"),
                      alert: "That time couldn't be booked: #{@booking.errors.full_messages.to_sentence}"
        end
        format.json { render json: @booking.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH /bookings/1/confirm
  def confirm
    authorize @booking
    change_status(notice: "Booking confirmed.") { @booking.location.with_lock { @booking.confirm! } }
  end

  # PATCH /bookings/1/decline
  def decline
    authorize @booking
    change_status(notice: "Booking declined.") { @booking.decline! }
  end

  # PATCH /bookings/1/cancel
  def cancel
    authorize @booking
    change_status(notice: "Booking cancelled.") { @booking.cancel! }
  end

  private

  def set_booking
    @booking = Booking.find(params.expect(:id))
  end

  def booking_params
    params.expect(booking: [ :started_at, :ended_at, :location_id ])
  end

  def change_status(notice:)
    yield
    redirect_to @booking, notice: notice, status: :see_other
  rescue ActiveRecord::RecordInvalid, Booking::InvalidTransition => e
    redirect_to @booking, alert: e.message, status: :see_other
  end
end
