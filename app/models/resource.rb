# == Schema Information
#
# Table name: resources
#
#  id          :bigint           not null, primary key
#  active      :boolean          default(TRUE), not null
#  name        :string           not null
#  position    :integer          default(0), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  location_id :bigint           not null
#
# The thing that actually gets booked at a location: a room, a chair, a
# barber. Each resource has its own calendar, so a location with three
# resources can take three bookings at the same time.
#
# Resources with bookings are never deleted, only made inactive, so old
# bookings still say who or what they were with.
class Resource < ApplicationRecord
  DEFAULT_NAME = "Main space".freeze

  belongs_to :location, inverse_of: :resources
  has_many :bookings, dependent: :restrict_with_error

  validates :name, presence: true, length: { maximum: 60 }

  scope :active, -> { where(active: true) }

  # Removes the resource, or retires it if bookings point at it.
  def retire!
    bookings.exists? ? update!(active: false) : destroy!
  end
end
