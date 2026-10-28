# A booking is private to its guest and the location's host.
#   - Guests request bookings, can change the times while it's pending,
#     and can cancel before it starts.
#   - Hosts confirm or decline pending requests, and can cancel before it starts.
class BookingPolicy < ApplicationPolicy
  def index? = user.present?
  def show? = guest? || host?

  def create?
    user.present? && record.location.present? && record.location.host_id != user.id
  end

  def update? = guest? && record.editable?
  def confirm? = host? && record.respondable?
  def decline? = host? && record.respondable?
  def cancel? = (guest? || host?) && record.cancellable?

  class Scope < ApplicationPolicy::Scope
    # Bookings the user made, plus bookings at locations they host.
    def resolve
      return scope.none if user.blank?

      scope.left_joins(:location)
        .where(guest_id: user.id)
        .or(scope.left_joins(:location).where(locations: { host_id: user.id }))
    end
  end

  private

  def guest?
    user.present? && record.guest_id == user.id
  end

  def host?
    user.present? && record.location&.host_id == user.id
  end
end
