# == Schema Information
#
# Table name: bookings
#
#  id          :bigint           not null, primary key
#  ended_at    :string
#  started_at  :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  guest_id    :integer
#  location_id :integer
#
class Booking < ApplicationRecord
  
  validates :started_at, presence: true
  validates :ended_at, presence: true
  validates :location_id, presence: true
  validates :guest_id, presence: true

  belongs_to :location
  belongs_to :user, class_name: "User", foreign_key: "guest_id"
end
