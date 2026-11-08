require "rails_helper"

RSpec.describe BusinessType, type: :model do
  let(:host) { create_user }

  def location_from(preset)
    location = host.locations.new(name: "My #{preset.name}", address: "1 Main St", city: "Chicago", state: "IL", postal_code: "60601")
    location.apply_business_type(preset.key)
    location
  end

  BusinessType.all.each do |preset|
    it "sets up a working #{preset.name.downcase}" do
      location = location_from(preset)
      expect(location.save).to be(true), location.errors.full_messages.to_sentence

      location.add_starter_setup!
      location.reload
      expect(location.business_type).to eq(preset.key)
      expect(location.resource_label).to eq(preset.resource_label)
      expect(location.services.map(&:name)).to eq(preset.services.map { |s| s[:name] })
      expect(location.resources.first.name).to eq(preset.resources.first)
      expect(location.slots_for(Date.current.next_occurring(:wednesday))).not_to be_empty
    end
  end

  it "falls back to a blank setup for unknown keys" do
    expect(BusinessType.fetch("spaceship")).to eq(BusinessType::OTHER)
  end

  it "doesn't add starter services twice" do
    location = location_from(BusinessType.find("barbershop")).tap(&:save!)
    2.times { location.add_starter_setup! }

    expect(location.services.count).to eq(3)
  end

  describe "booking links" do
    it "are made from the name" do
      expect(create_location(name: "Riverside Barbershop").slug).to eq("riverside-barbershop")
    end

    it "get a number when the name is taken" do
      create_location(name: "Fade Factory")
      expect(create_location(name: "Fade Factory").slug).to eq("fade-factory-2")
    end

    it "tidy up what the host types" do
      expect(create_location(slug: "My Shop!").slug).to eq("my-shop")
    end

    it "can't be taken twice" do
      create_location(slug: "the-spot")
      location = Location.new(slug: "the-spot")
      location.validate

      expect(location.errors[:slug]).to include("has already been taken")
    end

    it "can't use a reserved word" do
      location = Location.new(slug: "admin")
      location.validate

      expect(location.errors[:slug]).to include("is reserved")
    end
  end
end
