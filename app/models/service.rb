# == Schema Information
#
# Table name: services
#
#  id               :bigint           not null, primary key
#  active           :boolean          default(TRUE), not null
#  description      :string
#  duration_minutes :integer          not null
#  name             :string           not null
#  price_cents      :integer          default(0), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  location_id      :bigint           not null
#
# Something a guest can book, with a set length and price:
# "Fade, 45 min, $35" or "Mix & master, 2 hours, $150".
#
# The length has to be a whole number of the location's slots, so a service
# always lines up with the day view.
class Service < ApplicationRecord
  include MoneyField
  money_field :price

  belongs_to :location, inverse_of: :services
  has_many :bookings, dependent: :nullify

  validates :name, presence: true, length: { maximum: 80 }
  validates :description, length: { maximum: 300 }
  validates :duration_minutes, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 1440 }
  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :fits_the_slots

  scope :active, -> { where(active: true) }

  # How many of the location's slots this service takes up.
  def slot_count
    return 0 if location.blank? || location.slot_minutes.to_i.zero?

    duration_minutes.to_i / location.slot_minutes
  end

  # Removes the service, or retires it if bookings point at it.
  def retire!
    bookings.exists? ? update!(active: false) : destroy!
  end

  private

  def fits_the_slots
    return if location.blank? || duration_minutes.blank? || duration_minutes.to_i <= 0

    slot = location.slot_minutes
    return if (duration_minutes % slot).zero?

    errors.add(:duration_minutes, "must be a multiple of the #{slot}-minute slot length")
  end
end
