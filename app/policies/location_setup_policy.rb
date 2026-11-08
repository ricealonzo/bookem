# Services and resources belong to a location, and only its host can add,
# change or remove them.
class LocationSetupPolicy < ApplicationPolicy
  def index? = host?
  def create? = host?
  def update? = host?
  def destroy? = host?

  private

  def host?
    user.present? && record.location&.host_id == user.id
  end
end
