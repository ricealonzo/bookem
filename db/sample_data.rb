require "faker"

module SampleData
  HOST_COUNT = 10
  GUEST_COUNT = 20
  LOCATION_COUNT = 20
  BOOKING_COUNT = 50

  def self.load!(reset: true)
    if reset
      Booking.delete_all
      Location.delete_all
      User.delete_all
    end

    hosts = Array.new(HOST_COUNT) do |index|
      User.create!(
        email: "host#{index + 1}@example.com",
        password: "password",
        first_name: Faker::Name.first_name,
        last_name: Faker::Name.last_name,
        organization: Faker::Company.name,
        phone_number: Faker::PhoneNumber.phone_number,
        website: Faker::Internet.url
      )
    end

    guests = Array.new(GUEST_COUNT) do |index|
      User.create!(
        email: "guest#{index + 1}@example.com",
        password: "password",
        first_name: Faker::Name.first_name,
        last_name: Faker::Name.last_name,
        organization: Faker::Company.name,
        phone_number: Faker::PhoneNumber.phone_number,
        website: Faker::Internet.url
      )
    end

    locations = Array.new(LOCATION_COUNT) do
      Location.create!(
        name: Faker::Company.name,
        description: Faker::Lorem.sentence(word_count: 12),
        address: Faker::Address.street_address,
        city: Faker::Address.city,
        state: Faker::Address.state_abbr,
        postal_code: Faker::Address.postcode,
        host: hosts.sample
      )
    end

    BOOKING_COUNT.times do
      location = locations.sample
      guest = guests.sample
      start_date = Faker::Date.forward(days: 60)
      end_date = start_date + rand(1..7)

      Booking.create!(
        location: location,
        guest: guest,
        started_at: start_date.to_s,
        ended_at: end_date.to_s
      )
    end
  end
end
