require "rails_helper"

RSpec.describe BookingsHelper, type: :helper do
  let(:day) { Date.new(2030, 3, 12) }

  def booking(starts, ends)
    Booking.new(started_at: starts, ended_at: ends)
  end

  it "labels a booking within one day" do
    b = booking(Time.zone.local(2030, 3, 12, 10), Time.zone.local(2030, 3, 12, 12, 30))
    expect(helper.booking_time_label(b, day)).to eq("10 AM–12:30 PM")
  end

  it "labels the days of a multi-day booking" do
    b = booking(Time.zone.local(2030, 3, 11, 18), Time.zone.local(2030, 3, 13, 9))
    expect(helper.booking_time_label(b, Date.new(2030, 3, 11))).to eq("From 6 PM")
    expect(helper.booking_time_label(b, day)).to eq("All day")
    expect(helper.booking_time_label(b, Date.new(2030, 3, 13))).to eq("Until 9 AM")
  end

  it "doesn't count a booking that ends at midnight on the next day" do
    b = booking(Time.zone.local(2030, 3, 11, 20), Time.zone.local(2030, 3, 12, 0))
    expect(helper.bookings_on(day, [ b ])).to be_empty
  end

  it "falls back to the current month for a bad start_date" do
    expect(helper.calendar_month_start("nonsense")).to eq(Date.current.beginning_of_month)
    expect(helper.calendar_month_start("2030-03-17")).to eq(Date.new(2030, 3, 1))
  end

  it "describes a booking's full range" do
    b = booking(Time.zone.local(2030, 3, 12, 10), Time.zone.local(2030, 3, 12, 12))
    expect(helper.booking_range_label(b)).to eq("Tue, Mar 12, 10 AM–12 PM")
  end
end
