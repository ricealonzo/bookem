# Adds, renames and removes a location's resources (rooms, chairs, barbers).
# They're listed on the location's services page.
class ResourcesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_location

  # POST /locations/1/resources
  def create
    resource = Resource.new(resource_params.merge(location_id: @location.id, position: @location.resources.count))
    authorize resource

    if resource.save
      redirect_to location_services_path(@location), notice: "#{resource.name} added.", status: :see_other
    else
      redirect_to location_services_path(@location), alert: "That couldn't be added: #{resource.errors.full_messages.to_sentence}", status: :see_other
    end
  end

  # PATCH /locations/1/resources/2
  def update
    resource = @location.resources.find(params.expect(:id))
    authorize resource

    if resource.update(resource_params)
      redirect_to location_services_path(@location), notice: "#{resource.name} saved.", status: :see_other
    else
      redirect_to location_services_path(@location), alert: "That couldn't be saved: #{resource.errors.full_messages.to_sentence}", status: :see_other
    end
  end

  # DELETE /locations/1/resources/2
  # A location always keeps at least one. Ones with bookings are retired
  # instead of deleted, so old bookings still say who they were with.
  def destroy
    resource = @location.resources.find(params.expect(:id))
    authorize resource

    if resource.active? && @location.active_resources.size <= 1
      return redirect_to location_services_path(@location),
                         alert: "Keep at least one #{@location.resource_label.downcase} so guests can book.", status: :see_other
    end

    resource.retire!
    redirect_to location_services_path(@location), notice: "#{resource.name} removed.", status: :see_other
  end

  private

  def set_location
    @location = Location.find(params.expect(:location_id))
  end

  def resource_params
    params.expect(resource: [ :name ])
  end
end
