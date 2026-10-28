# Used by CI: checks that the booking-time conversion migration turned old
# text times into real timestamps and marked old bookings confirmed.
# Read through the model so times come back in the app's time zone: a
# booking typed in as 10:00 should still show as 10:00.
first = Booking.order(:id).first
row = {
  "started_at" => first.started_at&.strftime("%Y-%m-%d %H:%M"),
  "ended_at" => first.ended_at&.strftime("%Y-%m-%d %H:%M"),
  "status" => first.status
}
bad = { "started_at" => Booking.order(:id).last.started_at }

type = Booking.columns_hash["started_at"].type
abort "started_at is #{type}, expected datetime" unless type == :datetime
abort "status is #{row["status"]}, expected confirmed" unless row["status"] == "confirmed"
abort "started_at was not converted: #{row["started_at"].inspect}" unless row["started_at"].to_s.start_with?("2030-01-15 10:00")
abort "unreadable time should become NULL, got #{bad["started_at"].inspect}" unless bad["started_at"].nil?

puts "::notice::Booking migration converted text times correctly (#{row["started_at"]} -> #{row["ended_at"]}, #{row["status"]})"
