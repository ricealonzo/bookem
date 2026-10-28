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
    @bookings = @location.bookings.active.where.not(started_at: nil).where.not(ended_at: nil).includes(:guest)
    @booking = Booking.new(location: @location, guest: current_user)
  end

  # GET /locations/new
  def new
    @location = current_user.locations.new
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
        format.html { redirect_to @location, notice: "Location was successfully created." }
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

  def set_location
    @location = Location.find(params.expect(:id))
  end

  def location_params
    params.expect(location: [ :name, :description, :address, :city, :state, :postal_code, :image ])
  end
end
