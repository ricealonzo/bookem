require "rails_helper"

RSpec.describe Location, type: :model do
  let(:monday) { Date.current.next_occurring(:monday) }

  def location_with(hours, slot_minutes: 60)
    create_location(hours: hours, slot_minutes: slot_minutes)
  end

  it "starts new locations open Monday to Friday, 9 AM to 5 PM, when no hours are given" do
    location = Location.create!(name: "Plain", address: "1 Main St", city: "Chicago", state: "IL", postal_code: "60601", host: create_user)
    expect(location.opening_hours.map(&:weekday)).to eq([ 1, 2, 3, 4, 5 ])
    expect(location.hours_for(monday).opens_at_minute).to eq(540)
  end

  it "needs at least one open day" do
    location = create_location
    location.weekly_hours = {}
    expect(location).not_to be_valid
    expect(location.errors[:base]).to include("Choose at least one day when guests can book")
  end

  it "rejects closing times before opening times" do
    location = create_location
    location.weekly_hours = all_week_hours(opens: "17:00", closes: "09:00", days: [ 1 ])
    expect(location).not_to be_valid
  end

  it "treats a closing time of 12:00 AM as midnight" do
    location = location_with(all_week_hours(opens: "20:00", closes: "00:00", days: [ 1 ]))
    expect(location.slots_for(monday).last.ends_at).to eq(monday.next_day.in_time_zone.beginning_of_day)
  end

  describe "slots" do
    let(:location) { location_with(all_week_hours(opens: "09:00", closes: "17:00", days: 1..5), slot_minutes: 120) }

    it "splits a day's hours into slots" do
      slots = location.slots_for(monday)
      expect(slots.map { |slot| slot.starts_at.hour }).to eq([ 9, 11, 13, 15 ])
      expect(slots.last.ends_at.hour).to eq(17)
    end

    it "has no slots on closed days" do
      expect(location.slots_for(monday + 5)).to be_empty
    end

    it "marks booked, requested and open slots" do
      starts = location.time_on(monday + 7, 540)
      create_booking(location: location, starts: starts, hours: 2).confirm!
      create_booking(location: location, starts: starts + 4.hours, hours: 2)

      states = location.schedule_for(monday + 7).map(&:state)
      expect(states).to eq(%i[booked open requested open])
    end

    it "marks slots that have started as past" do
      now = location.time_on(monday, 600) # 10 AM
      states = location.schedule_for(monday, [], now: now).map(&:state)
      expect(states).to eq(%i[past open open open])
    end
  end

  describe "booking within hours" do
    let(:location) { location_with(all_week_hours(opens: "09:00", closes: "17:00", days: 1..5), slot_minutes: 60) }
    let(:day) { monday + 7 }

    it "accepts whole slots inside the hours" do
      expect(location.bookable_range?(location.time_on(day, 600), location.time_on(day, 780))).to be(true)
    end

    it "rejects times outside the hours" do
      expect(location.bookable_range?(location.time_on(day, 960), location.time_on(day, 1080))).to be(false)
    end

    it "rejects times that don't line up with the slots" do
      expect(location.bookable_range?(location.time_on(day, 570), location.time_on(day, 630))).to be(false)
    end

    it "rejects closed days" do
      saturday = day + 5
      expect(location.booking_hours_problem(location.time_on(saturday, 600), location.time_on(saturday, 660))).to include("isn't open on Saturdays")
    end
  end
end
