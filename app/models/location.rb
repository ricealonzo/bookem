# == Schema Information
#
# Table name: locations
#
#  id          :bigint           not null, primary key
#  address     :string
#  city        :string
#  description :string
#  image       :string
#  name        :string
#  postal_code :string
#  state       :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  host_id     :integer
#
class Location < ApplicationRecord
  validates :name, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 2000 }
  validates :address, presence: true
  validates :city, presence: true
  validates :state, presence: true
  validates :postal_code, presence: true

  belongs_to :host, class_name: "User", foreign_key: "host_id", counter_cache: true

  has_many :bookings, class_name: "Booking", foreign_key: "location_id", dependent: :destroy

  mount_uploader :image, ImageUploader

  def full_address
    [ address, city, state, postal_code ].compact_blank.join(", ")
  end

  def hosted_by?(user)
    user.present? && host_id == user.id
  end
end
