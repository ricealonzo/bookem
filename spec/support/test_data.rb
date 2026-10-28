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

  def create_location(host: create_user, **attrs)
    Location.create!(
      name: "Test Studio",
      description: "A place to book",
      address: "1 Main St",
      city: "Chicago",
      state: "IL",
      postal_code: "60601",
      host: host,
      **attrs
    )
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
