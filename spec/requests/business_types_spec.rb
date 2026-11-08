require "rails_helper"

RSpec.describe "Business types and booking links", type: :request do
  let(:host) { create_user }

  describe "landing pages" do
    it "lists every kind of business" do
      get business_types_path
      expect(response).to have_http_status(:ok)
      BusinessType.all.each { |type| expect(response.body).to include(type.name) }
    end

    BusinessType.all.each do |type|
      it "has a page for #{type.plural}" do
        get business_type_path(type.key)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(type.headline, new_location_path(type: type.key))
      end
    end

    it "returns 404 for an unknown kind" do
      get business_type_path("spaceship")
      expect(response).to have_http_status(:not_found)
    end

    it "links to them from the home page" do
      get root_path
      expect(response.body).to include(business_type_path("barbershop"))
    end
  end

  describe "the booking link" do
    it "opens the location page" do
      location = create_location(host: host, name: "Riverside Barbershop")
      get booking_page_path("riverside-barbershop")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(location.name)
    end

    it "is shown to the host with a copy button" do
      location = create_location(host: host)
      sign_in host
      get location_path(location)

      expect(response.body).to include("/b/#{location.slug}", "Copy link")
    end

    it "is a 404 when no location has it" do
      get booking_page_path("nobody-here")
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "listing a new location" do
    before { sign_in host }

    it "asks what kind of business it is first" do
      get new_location_path
      expect(response.body).to include("What kind of business is it?", new_location_path(type: "barbershop"))
    end

    it "fills in the form for the chosen kind" do
      get new_location_path(type: "barbershop")

      expect(response.body).to include("List your barbershop")
      expect(response.body).to include(%(value="Barber"))
      expect(response.body).to include(%(selected="selected" value="30"))
    end

    it "adds starter services and names the first resource" do
      post locations_path, params: { location: {
        name: "Fade Factory", address: "1 Main St", city: "Chicago", state: "IL", postal_code: "60601",
        business_type: "barbershop", resource_label: "Barber", slot_minutes: 30,
        weekly_hours: BusinessType.weekly_hours(BusinessType.find("barbershop"))
      } }

      location = Location.last
      expect(response).to redirect_to(location_path(location))
      expect(location.slug).to eq("fade-factory")
      expect(location.services.pluck(:name)).to include("Haircut")
      expect(location.resources.first.name).to eq("Chair 1")
      expect(flash[:notice]).to include("starter services")
    end
  end
end
