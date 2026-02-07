class Location < ApplicationRecord

  belongs_to :host, required: true, class_name: "User", foreign_key: "host_id", counter_cache: true

  has_many  :bookings, class_name: "Booking", foreign_key: "location_id", dependent: :destroy
  
end
