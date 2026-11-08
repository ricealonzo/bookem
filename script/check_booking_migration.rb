# Used by CI: checks that the booking-time conversion migration turned old
# text times into real timestamps and marked old bookings confirmed, and
# that every location got a resource.
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

# Resources and services: the old location gets one resource, and its
# booking is moved onto it.
resource = first.resource
abort "old booking wasn't given a resource" if resource.nil?
abort "old location's resource is #{resource.name.inspect}, expected \"Main space\"" unless resource.name == "Main space"
abort "old booking should have no service" unless first.service_id.nil?
puts "::notice::Old booking moved onto the location's #{resource.name.inspect} resource"

# Booking links: old locations get a slug from their name and id.
slug = first.location.slug
abort "old location's slug is #{slug.inspect}, expected \"old-studio-1\"" unless slug == "old-studio-1"
puts "::notice::Old location's booking link is /b/#{slug}"

puts "::notice::Booking migration converted text times correctly (#{row["started_at"]} -> #{row["ended_at"]}, #{row["status"]})"
