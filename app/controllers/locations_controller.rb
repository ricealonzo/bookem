class LocationsController < ApplicationController
  before_action :authenticate_user!, except: %i[ index show ]
  before_action :set_location, only: %i[ show edit update destroy ]

  # GET /locations or /locations.json
  def index
    authorize Location
    @locations = policy_scope(Location).includes(:host).order(:created_at)
  end

  # GET /locations/1 or /locations/1.json
  def show
    authorize @location
    @bookings = @location.bookings.active.where.not(started_at: nil).where.not(ended_at: nil).includes(:guest).to_a
    @selected_date = (Date.iso8601(params[:date].to_s) rescue nil)
    # Guests can look at one resource's calendar ("Marcus" or "Studio B").
    @resource = @location.active_resources.detect { |resource| resource.id.to_s == params[:resource_id].to_s }
  end

  # GET /locations/new and /locations/new?type=barbershop
  # Hosts pick what kind of business they run first; the form then starts
  # with that business's usual hours, slot length and wording.
  def new
    @location = current_user.locations.new
    @business_type = BusinessType.find(params[:type])
    @choosing_type = params[:type].blank?
    if @business_type
      @location.apply_business_type(@business_type.key)
    else
      Location::DEFAULT_HOURS.each { |attrs| @location.opening_hours.build(attrs) }
    end
    authorize @location
  end

  # GET /locations/1/edit
  def edit
    authorize @location
  end

  # POST /locations or /locations.json
  def create
    @location = current_user.locations.new(location_params)
    authorize @location

    respond_to do |format|
      if @location.save
        @location.add_starter_setup!
        format.html { redirect_to @location, notice: created_notice }
        format.json { render :show, status: :created, location: @location }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @location.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /locations/1 or /locations/1.json
  def update
    authorize @location

    respond_to do |format|
      if @location.update(location_params)
        format.html { redirect_to @location, notice: "Location was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @location }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @location.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /locations/1 or /locations/1.json
  def destroy
    authorize @location
    @location.destroy!

    respond_to do |format|
      format.html { redirect_to locations_path, notice: "Location was successfully deleted.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private

  # /locations/7 or the booking link /b/riverside-barbershop
  def set_location
    @location = params[:slug].present? ? Location.find_by!(slug: params[:slug]) : Location.find(params.expect(:id))
  end

  def created_notice
    return "Location was successfully created." unless @location.services.exists?

    "Location created with some starter services. Change them, and add your #{@location.resource_label_plural}, on the services page."
  end

  def location_params
    hours = (0..6).to_h { |weekday| [ weekday.to_s, [ :open, :opens_at, :closes_at ] ] }
    params.require(:location).permit(
      :name, :description, :address, :city, :state, :postal_code, :image, :slot_minutes,
      :resource_label, :slot_price_dollars, :deposit_percent, :business_type, :slug,
      weekly_hours: hours
    )
  end
end
