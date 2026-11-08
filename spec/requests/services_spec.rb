require "rails_helper"

RSpec.describe "Services and resources setup", type: :request do
  let(:host) { create_user }
  let(:guest) { create_user }
  let(:location) { create_location(host: host, slot_minutes: 30) }
  let(:start) { 4.days.from_now.change(hour: 10) }

  describe "the setup page" do
    it "is only for the host" do
      sign_in guest
      get location_services_path(location)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("You're not allowed to do that.")
    end

    it "asks visitors to log in" do
      get location_services_path(location)
      expect(response).to redirect_to(new_user_session_path)
    end

    it "lists the host's services and resources" do
      location.services.create!(name: "Fade", duration_minutes: 60, price_cents: 3500)
      sign_in host
      get location_services_path(location)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Fade", "$35", "Main space")
    end
  end

  describe "services" do
    it "lets the host add one with a price in dollars" do
      sign_in host
      expect {
        post location_services_path(location), params: { service: { name: "Fade", duration_minutes: 60, price_dollars: "35.50" } }
      }.to change(Service, :count).by(1)

      service = Service.last
      expect(service.location).to eq(location)
      expect(service.price_cents).to eq(3550)
      expect(response).to redirect_to(location_services_path(location))
    end

    it "explains why a service couldn't be added" do
      sign_in host
      post location_services_path(location), params: { service: { name: "Odd", duration_minutes: 45 } }

      expect(Service.count).to eq(0)
      expect(flash[:alert]).to include("multiple of the 30-minute slot length")
    end

    it "won't let other users add services" do
      sign_in guest
      expect {
        post location_services_path(location), params: { service: { name: "Fade", duration_minutes: 60 } }
      }.not_to change(Service, :count)
    end

    it "retires a service that has bookings instead of deleting it" do
      service = location.services.create!(name: "Fade", duration_minutes: 60)
      create_booking(location: location, guest: guest, starts: start, hours: 1, service: service)
      sign_in host

      delete location_service_path(location, service)
      expect(service.reload).not_to be_active
    end
  end

  describe "resources" do
    it "lets the host add and rename them" do
      sign_in host
      post location_resources_path(location), params: { resource: { name: "Dee" } }
      dee = location.resources.find_by(name: "Dee")
      expect(dee).to be_present

      patch location_resource_path(location, dee), params: { resource: { name: "Dee B." } }
      expect(dee.reload.name).to eq("Dee B.")
    end

    it "keeps at least one" do
      sign_in host
      only = location.resources.first

      delete location_resource_path(location, only)
      expect(only.reload).to be_active
      expect(flash[:alert]).to include("Keep at least one room")
    end

    it "won't let other users change them" do
      sign_in guest
      patch location_resource_path(location, location.resources.first), params: { resource: { name: "Hacked" } }
      expect(location.resources.first.reload.name).to eq("Main space")
    end
  end

  describe "booking with a service and resource" do
    let!(:fade) { location.services.create!(name: "Fade", duration_minutes: 60, price_cents: 3500) }
    let!(:dee) { location.resources.create!(name: "Dee", position: 1) }

    def params_for(**extra)
      { booking: { started_at: start.strftime("%Y-%m-%dT%H:%M"), ended_at: (start + 30.minutes).strftime("%Y-%m-%dT%H:%M"),
                   location_id: location.id, **extra } }
    end

    it "books the service's full length with the chosen resource" do
      sign_in guest
      post bookings_path, params: params_for(service_id: fade.id, resource_id: dee.id)

      booking = Booking.last
      expect(booking.service).to eq(fade)
      expect(booking.resource).to eq(dee)
      expect(booking.ended_at).to eq(start + 60.minutes)
      expect(booking.price_cents).to eq(3500)
    end

    it "refuses a booking without a service and says so" do
      sign_in guest
      expect { post bookings_path, params: params_for }.not_to change(Booking, :count)
      expect(flash[:alert]).to include("Choose a service")
    end

    it "ignores a resource from another location" do
      other = create_location.resources.first
      sign_in guest
      post bookings_path, params: params_for(service_id: fade.id, resource_id: other.id)

      expect(Booking.last.resource.location).to eq(location)
    end

    it "shows services and the resource picker on the location page" do
      sign_in guest
      get location_path(location)

      expect(response.body).to include("Fade", "Choose a service", "Any available", "Dee")
    end

    it "shows one resource's calendar when picked" do
      create_booking(location: location, guest: create_user, starts: start, hours: 1, service: fade, resource: dee)
      sign_in guest

      get location_path(location, resource_id: dee.id, date: start.to_date.iso8601)
      expect(response.body).to include(%(selected="selected" value="#{dee.id}"))
    end
  end
end
