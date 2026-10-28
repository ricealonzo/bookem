# Used by CI: checks that the booking-time conversion migration turned old
# text times into real timestamps and marked old bookings confirmed.
row = ActiveRecord::Base.connection.select_one("SELECT started_at, ended_at, status FROM bookings ORDER BY id LIMIT 1")
bad = ActiveRecord::Base.connection.select_one("SELECT started_at FROM bookings ORDER BY id DESC LIMIT 1")

type = Booking.columns_hash["started_at"].type
abort "started_at is #{type}, expected datetime" unless type == :datetime
abort "status is #{row["status"]}, expected confirmed" unless row["status"] == "confirmed"
abort "started_at was not converted: #{row["started_at"].inspect}" unless row["started_at"].to_s.start_with?("2030-01-15 10:00")
abort "unreadable time should become NULL, got #{bad["started_at"].inspect}" unless bad["started_at"].nil?

puts "::notice::Booking migration converted text times correctly (#{row["started_at"]} -> #{row["ended_at"]}, #{row["status"]})"
