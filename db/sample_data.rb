require "faker"

module SampleData
  HOST_COUNT = 10
  GUEST_COUNT = 20
  BOOKING_COUNT = 50
  LOCATIONS = [
    {
      name: "Northside Creative Studio",
      description: "Bright, flexible studio for photo, video, and small workshops.",
      address: "2140 Market St",
      city: "San Francisco",
      state: "CA",
      postal_code: "94114",
      image_file: "studio.jpg",
      slot_minutes: 120,
      hours: { days: 1..6, opens: "09:00", closes: "21:00" }
    },
    {
      name: "Downtown Event Loft",
      description: "Open-plan event space with lounge seating and modular layouts.",
      address: "825 W Jackson Blvd",
      city: "Chicago",
      state: "IL",
      postal_code: "60607",
      image_file: "event_space.jpg",
      slot_minutes: 240,
      hours: { days: [ 4, 5, 6, 0 ], opens: "10:00", closes: "22:00" }
    },
    {
      name: "Riverside Barbershop",
      description: "Modern barbershop with multiple stations and waiting area.",
      address: "310 S 1st St",
      city: "Austin",
      state: "TX",
      postal_code: "78704",
      image_file: "barbershop.jpg",
      slot_minutes: 30,
      hours: { days: 2..6, opens: "09:00", closes: "18:00" }
    },
    {
      name: "Sunset Beauty Salon",
      description: "Full-service salon with styling chairs and wash stations.",
      address: "4889 Mission St",
      city: "San Francisco",
      state: "CA",
      postal_code: "94112",
      image_file: "salon.jpg",
      slot_minutes: 60,
      hours: { days: 2..6, opens: "10:00", closes: "19:00" }
    },
    {
      name: "Brickhouse Photo Studio",
      description: "Cyclorama wall, grip gear, and natural light for shoots.",
      address: "1200 E 6th St",
      city: "Los Angeles",
      state: "CA",
      postal_code: "90021",
      image_file: "photo_studio.jpg",
      slot_minutes: 120,
      hours: { days: 1..5, opens: "08:00", closes: "20:00" }
    },
    {
      name: "Greenline Wellness Studio",
      description: "Calm, airy studio for yoga classes, wellness sessions, and pop-ups.",
      address: "1400 W 50th St",
      city: "Denver",
      state: "CO",
      postal_code: "80212",
      image_file: "wellness.jpg",
      slot_minutes: 60,
      hours: { days: 0..6, opens: "07:00", closes: "21:00" }
    }
  ].freeze

  # { days: 1..5, opens: "09:00", closes: "17:00" } as the location form sends it.
  def self.weekly_hours(hours)
    hours[:days].to_a.to_h do |weekday|
      [ weekday.to_s, { "open" => "1", "opens_at" => hours[:opens], "closes_at" => hours[:closes] } ]
    end
  end

  def self.sample_image_path(filename)
    Rails.root.join("db", "sample_images", filename)
  end

  def self.sample_image_file(filename)
    path = sample_image_path(filename)
    unless File.exist?(path)
      raise "Missing sample image: #{path}. Add a real photo there before running rails sample_data."
    end
    File.open(path)
  end

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

    locations = LOCATIONS.map do |location|
      Location.create!(
        name: location[:name],
        description: location[:description],
        address: location[:address],
        city: location[:city],
        state: location[:state],
        postal_code: location[:postal_code],
        image: sample_image_file(location[:image_file]),
        slot_minutes: location[:slot_minutes],
        weekly_hours: weekly_hours(location[:hours]),
        host: hosts.sample
      )
    end

    # Random future bookings of one to three slots. Ones that clash with an
    # earlier booking are skipped, since the app doesn't allow double-booking.
    BOOKING_COUNT.times do
      location = locations.sample
      slots = location.slots_for(Date.current + rand(1..45))
      next if slots.empty?

      first = rand(slots.size)
      last = [ first + rand(0..2), slots.size - 1 ].min

      Booking.new(
        location: location,
        guest: guests.sample,
        started_at: slots[first].starts_at,
        ended_at: slots[last].ends_at,
        status: %w[pending confirmed confirmed].sample
      ).save
    end
  end
end
