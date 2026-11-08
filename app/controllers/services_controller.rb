# The host's setup page for a location: the services guests can book and the
# resources (rooms, chairs, barbers) that get booked. Resources are added and
# changed by ResourcesController, but listed here too.
class ServicesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_location

  # GET /locations/1/services
  def index
    # location_id instead of location: so the blank form records aren't
    # added to the location's lists.
    authorize Service.new(location_id: @location.id)
    @services = @location.services.to_a
    @resources = @location.resources.to_a
  end

  # POST /locations/1/services
  def create
    service = Service.new(service_params.merge(location_id: @location.id))
    authorize service

    if service.save
      redirect_to location_services_path(@location), notice: "#{service.name} added.", status: :see_other
    else
      redirect_to location_services_path(@location), alert: "That service couldn't be added: #{service.errors.full_messages.to_sentence}", status: :see_other
    end
  end

  # PATCH /locations/1/services/2
  def update
    service = @location.services.find(params.expect(:id))
    authorize service

    if service.update(service_params)
      redirect_to location_services_path(@location), notice: "#{service.name} saved.", status: :see_other
    else
      redirect_to location_services_path(@location), alert: "That service couldn't be saved: #{service.errors.full_messages.to_sentence}", status: :see_other
    end
  end

  # DELETE /locations/1/services/2
  # Services that have bookings are retired instead, so old bookings keep them.
  def destroy
    service = @location.services.find(params.expect(:id))
    authorize service
    service.retire!

    redirect_to location_services_path(@location), notice: "#{service.name} removed.", status: :see_other
  end

  private

  def set_location
    @location = Location.find(params.expect(:location_id))
  end

  def service_params
    params.expect(service: [ :name, :description, :duration_minutes, :price_dollars ])
  end
end
