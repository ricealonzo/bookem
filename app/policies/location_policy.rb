# Anyone can browse locations. Signed-in users can list a location, and only
# its host can change or remove it.
class LocationPolicy < ApplicationPolicy
  def index? = true
  def show? = true
  def create? = user.present?
  def update? = host?
  def destroy? = host?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end

  private

  def host?
    user.present? && record.host_id == user.id
  end
end
