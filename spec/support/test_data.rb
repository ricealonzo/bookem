# Small helpers for building records in specs.
module TestData
  def create_user(**attrs)
    @user_sequence = (@user_sequence || 0) + 1
    User.create!(
      email: "user#{@user_sequence}-#{SecureRandom.hex(3)}@example.com",
      password: "password123",
      first_name: "Test",
      last_name: "User#{@user_sequence}",
      **attrs
    )
  end

  # Open every day, all day, in 1-hour slots unless told otherwise.
  def create_location(host: create_user, hours: all_week_hours, **attrs)
    Location.create!(
      name: "Test Studio",
      description: "A place to book",
      address: "1 Main St",
      city: "Chicago",
      state: "IL",
      postal_code: "60601",
      host: host,
      weekly_hours: hours,
      **attrs
    )
  end

  def all_week_hours(opens: "00:00", closes: "00:00", days: 0..6)
    days.to_a.to_h { |weekday| [ weekday.to_s, { "open" => "1", "opens_at" => opens, "closes_at" => closes } ] }
  end

  def create_booking(location: create_location, guest: create_user, starts: 2.days.from_now.beginning_of_hour, hours: 2, **attrs)
    Booking.create!(
      location: location,
      guest: guest,
      started_at: starts,
      ended_at: starts + hours.hours,
      **attrs
    )
  end
end
