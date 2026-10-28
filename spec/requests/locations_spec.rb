require "rails_helper"

RSpec.describe "Locations", type: :request do
  let(:host) { create_user }
  let(:stranger) { create_user }
  let!(:location) { create_location(host: host, name: "Host's Studio") }

  let(:location_params) do
    { location: { name: "New Place", address: "2 Elm St", city: "Chicago", state: "IL", postal_code: "60602" } }
  end

  it "lets anyone browse locations" do
    get locations_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Host&#39;s Studio")

    get location_path(location)
    expect(response).to have_http_status(:ok)
  end

  it "asks visitors to log in before booking" do
    get location_path(location)
    expect(response.body).to include("to request a booking")
  end

  describe "creating" do
    it "requires signing in" do
      expect { post locations_path, params: location_params }.not_to change(Location, :count)
      expect(response).to redirect_to(new_user_session_path)
    end

    it "makes the signed-in user the host, ignoring any host_id sent" do
      sign_in stranger
      post locations_path, params: { location: location_params[:location].merge(host_id: host.id) }
      expect(Location.last.host).to eq(stranger)
    end
  end

  describe "editing and deleting" do
    it "is allowed for the host" do
      sign_in host
      patch location_path(location), params: { location: { name: "Renamed" } }
      expect(location.reload.name).to eq("Renamed")

      expect { delete location_path(location) }.to change(Location, :count).by(-1)
    end

    it "is refused for other users" do
      sign_in stranger

      get edit_location_path(location)
      expect(response).to redirect_to(root_path)

      patch location_path(location), params: { location: { name: "Hijacked" } }
      expect(location.reload.name).to eq("Host's Studio")

      expect { delete location_path(location) }.not_to change(Location, :count)
    end

    it "is refused for visitors" do
      patch location_path(location), params: { location: { name: "Hijacked" } }
      expect(response).to redirect_to(new_user_session_path)
      expect(location.reload.name).to eq("Host's Studio")
    end
  end

  it "doesn't show guests' details to the public" do
    guest = create_user(first_name: "Secretname")
    create_booking(location: location, guest: guest)

    get location_path(location)
    expect(response.body).not_to include("Secretname")
    expect(response.body).not_to include(guest.email)
  end

  describe "opening hours" do
    it "lets the host set hours and slot length" do
      sign_in host
      patch location_path(location), params: {
        location: {
          slot_minutes: 120,
          weekly_hours: {
            "1" => { open: "1", opens_at: "08:00", closes_at: "12:00" },
            "2" => { open: "0", opens_at: "09:00", closes_at: "17:00" }
          }
        }
      }

      location.reload
      expect(location.slot_minutes).to eq(120)
      expect(location.opening_hours.map(&:weekday)).to eq([ 1 ])
      expect(location.opening_hours.first.opens_at_minute).to eq(480)
    end

    it "shows the hours on the location page" do
      location.update!(weekly_hours: all_week_hours(opens: "09:00", closes: "17:00", days: 1..5))
      get location_path(location)
      expect(response.body).to include("Monday to Friday")
      expect(response.body).to include("9 AM to 5 PM")
    end
  end
end
