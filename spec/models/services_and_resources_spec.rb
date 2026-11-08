require "rails_helper"

RSpec.describe "Services and resources", type: :model do
  let(:host) { create_user }
  let(:guest) { create_user }
  let(:location) { create_location(host: host, slot_minutes: 30) }
  let(:start) { 3.days.from_now.change(hour: 10) }

  def book(starts: start, ends: start + 30.minutes, guest: create_user, **attrs)
    Booking.new(location: location, guest: guest, started_at: starts, ended_at: ends, **attrs)
  end

  describe "a new location" do
    it "starts with one resource called Main space" do
      expect(location.resources.map(&:name)).to eq([ "Main space" ])
    end

    it "is called a Room until the host changes it" do
      expect(location.resource_label).to eq("Room")
    end
  end

  describe "resources" do
    let!(:marcus) { location.resources.first.tap { |r| r.update!(name: "Marcus") } }
    let!(:dee) { location.resources.create!(name: "Dee", position: 1) }

    before { location.reload }

    it "puts a booking on the first free resource" do
      first = book.tap(&:save!)
      second = book.tap(&:save!)

      expect(first.resource).to eq(marcus)
      expect(second.resource).to eq(dee)
    end

    it "refuses a booking when every resource is taken" do
      2.times { book.save! }
      third = book

      expect(third).not_to be_valid
      expect(third.errors[:base]).to include("Every room is booked at that time")
    end

    it "says who's busy when the guest picked someone" do
      book(resource: dee).save!
      clash = book(resource: dee)

      expect(clash).not_to be_valid
      expect(clash.errors[:base]).to include("Dee is already booked at that time")
    end

    it "won't book a resource from another location" do
      other = create_location.resources.first
      booking = book(resource: other)

      expect(booking).not_to be_valid
      expect(booking.errors[:resource]).to include("isn't part of this location")
    end

    it "won't book a retired resource" do
      dee.update!(active: false)
      booking = book(resource: dee)

      expect(booking).not_to be_valid
      expect(booking.errors[:resource]).to include("isn't taking bookings anymore")
    end

    it "keeps a slot open until every resource is booked" do
      date = start.to_date
      book.save!
      slot = location.reload.schedule_for(date).detect { |s| s.starts_at == start }
      expect(slot.state).to eq(:open)
      expect(slot.free_count).to eq(1)

      book.save!
      slot = location.reload.schedule_for(date).detect { |s| s.starts_at == start }
      expect(slot.state).to eq(:requested)
    end

    it "shows one resource's own calendar" do
      book(resource: marcus).save!
      schedule = location.reload.schedule_for(start.to_date, resource: marcus)
      expect(schedule.detect { |s| s.starts_at == start }.state).to eq(:requested)

      schedule = location.schedule_for(start.to_date, resource: dee)
      expect(schedule.detect { |s| s.starts_at == start }.state).to eq(:open)
    end

    it "is retired instead of deleted once it has bookings" do
      book(resource: dee).save!
      dee.retire!

      expect(dee.reload).not_to be_active
      expect(location.reload.active_resources).to eq([ marcus ])
    end
  end

  describe "services" do
    let!(:fade) { location.services.create!(name: "Fade", duration_minutes: 60, price_cents: 3500) }

    before { location.reload }

    it "sets the booking's length from the service, ignoring the end time sent" do
      booking = book(service: fade, ends: start + 4.hours)
      booking.save!

      expect(booking.ended_at).to eq(start + 60.minutes)
    end

    it "stores the service's price on the booking" do
      booking = book(service: fade).tap(&:save!)
      fade.update!(price_cents: 5000)

      expect(booking.reload.price_cents).to eq(3500)
      expect(booking.price_label).to eq("$35.00")
    end

    it "requires a service once the location offers any" do
      booking = book

      expect(booking).not_to be_valid
      expect(booking.errors[:base]).to include("Choose a service to book")
    end

    it "won't use another location's service" do
      other = create_location(slot_minutes: 30).services.create!(name: "Trim", duration_minutes: 30)
      booking = book(service: other)

      expect(booking).not_to be_valid
      expect(booking.errors[:service]).to include("isn't offered at this location")
    end

    it "must line up with the location's slots" do
      service = location.services.new(name: "Odd", duration_minutes: 45)

      expect(service).not_to be_valid
      expect(service.errors[:duration_minutes]).to include("must be a multiple of the 30-minute slot length")
    end

    it "stops the host from picking a slot length the services don't fit" do
      location.slot_minutes = 120

      expect(location).not_to be_valid
      expect(location.errors[:slot_minutes].first).to include("Fade")
    end

    it "counts how many slots it takes" do
      expect(fade.slot_count).to eq(2)
    end
  end

  describe "pricing without services" do
    it "charges the slot price for each slot booked" do
      location.update!(slot_price_cents: 2000)
      booking = book(ends: start + 90.minutes).tap(&:save!)

      expect(booking.price_cents).to eq(6000)
    end

    it "is free when the host hasn't set a price" do
      expect(book.tap(&:save!).price_cents).to eq(0)
    end
  end

  describe "MoneyField" do
    it "reads dollars typed into a form" do
      expect(MoneyField.to_cents("35")).to eq(3500)
      expect(MoneyField.to_cents("$1,200.50")).to eq(120_050)
      expect(MoneyField.to_cents("")).to eq(0)
      expect(MoneyField.to_cents("abc")).to eq(0)
    end

    it "shows cents as dollars" do
      expect(Service.new(price_cents: 3550).price_dollars).to eq("35.50")
    end
  end
end
