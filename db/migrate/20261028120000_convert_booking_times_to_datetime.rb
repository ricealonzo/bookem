# Booking times were stored as text. This converts them to real timestamps,
# parsing each existing value in Ruby so odd formats don't break the deploy.
# Values that can't be parsed become NULL.
class ConvertBookingTimesToDatetime < ActiveRecord::Migration[8.0]
  class MigrationBooking < ActiveRecord::Base
    self.table_name = "bookings"
  end

  def up
    rename_column :bookings, :started_at, :started_at_text
    rename_column :bookings, :ended_at, :ended_at_text
    add_column :bookings, :started_at, :datetime
    add_column :bookings, :ended_at, :datetime

    MigrationBooking.reset_column_information
    MigrationBooking.find_each do |booking|
      booking.update_columns(
        started_at: parse_time(booking.started_at_text),
        ended_at: parse_time(booking.ended_at_text)
      )
    end

    remove_column :bookings, :started_at_text
    remove_column :bookings, :ended_at_text
  end

  def down
    change_column :bookings, :started_at, :string
    change_column :bookings, :ended_at, :string
  end

  private

  def parse_time(value)
    return nil if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError
    nil
  end
end
