require "rails_helper"

RSpec.describe Booking, type: :model do
  let(:host) { create_user }
  let(:guest) { create_user }
  let(:location) { create_location(host: host) }
  let(:start) { 3.days.from_now.change(hour: 10) }

  def build_booking(starts: start, ends: start + 2.hours, **attrs)
    Booking.new(location: location, guest: guest, started_at: starts, ended_at: ends, **attrs)
  end

  it "is valid with a future time range" do
    expect(build_booking).to be_valid
  end

  it "starts out pending" do
    expect(build_booking.status).to eq("pending")
  end

  it "stores real timestamps" do
    booking = build_booking
    booking.save!
    expect(booking.reload.started_at).to be_a(ActiveSupport::TimeWithZone)
  end

  it "requires the end to be after the start" do
    booking = build_booking(ends: start - 1.hour)
    expect(booking).not_to be_valid
    expect(booking.errors[:ended_at]).to include("must be after the start time")
  end

  it "rejects a zero-length booking" do
    expect(build_booking(ends: start)).not_to be_valid
  end

  it "rejects bookings in the past" do
    booking = build_booking(starts: 2.days.ago, ends: 2.days.ago + 1.hour)
    expect(booking).not_to be_valid
    expect(booking.errors[:started_at]).to include("must be in the future")
  end

  it "rejects bookings longer than 30 days" do
    expect(build_booking(ends: start + 31.days)).not_to be_valid
  end

  it "doesn't let hosts book their own location" do
    booking = Booking.new(location: location, guest: host, started_at: start, ended_at: start + 1.hour)
    expect(booking).not_to be_valid
    expect(booking.errors[:base]).to include("You can't book your own location")
  end

  describe "double-booking" do
    before { build_booking.save! }

    it "rejects an overlapping booking at the same location" do
      clash = build_booking(starts: start + 1.hour, ends: start + 3.hours, guest: create_user)
      expect(clash).not_to be_valid
      expect(clash.errors[:base]).to include("That time overlaps another booking for this location")
    end

    it "allows a booking that starts exactly when the other ends" do
      expect(build_booking(starts: start + 2.hours, ends: start + 4.hours, guest: create_user)).to be_valid
    end

    it "allows the same time at a different location" do
      other = Booking.new(location: create_location, guest: guest, started_at: start, ended_at: start + 2.hours)
      expect(other).to be_valid
    end

    it "frees the slot when the booking is cancelled" do
      Booking.last.cancel!
      expect(build_booking(guest: create_user)).to be_valid
    end
  end

  describe "status changes" do
    let(:booking) { build_booking.tap(&:save!) }

    it "can be confirmed or declined while pending" do
      booking.confirm!
      expect(booking.reload).to be_confirmed
    end

    it "can't be confirmed after it was declined" do
      booking.decline!
      expect { booking.confirm! }.to raise_error(Booking::InvalidTransition)
    end

    it "can be cancelled before it starts" do
      booking.cancel!
      expect(booking.reload).to be_cancelled
    end

    it "can't be cancelled twice" do
      booking.cancel!
      expect { booking.cancel! }.to raise_error(Booking::InvalidTransition)
    end

    it "only allows changing times while pending" do
      expect(booking).to be_editable
      booking.confirm!
      expect(booking).not_to be_editable
    end
  end
end
