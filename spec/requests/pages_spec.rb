require "rails_helper"

# Every page renders for the people who can see it.
RSpec.describe "Pages", type: :request do
  let(:host) { create_user }
  let(:guest) { create_user }
  let(:location) { create_location(host: host) }
  let!(:booking) { create_booking(location: location, guest: guest) }

  it "shows the booking form to a signed-in guest" do
    sign_in guest
    get location_path(location)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Request Booking")
  end

  it "tells hosts where to find requests instead of showing a booking form" do
    sign_in host
    get location_path(location)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Your Location")
    expect(response.body).not_to include("Request Booking")
  end

  it "renders the new booking page" do
    sign_in guest
    get new_booking_path(location_id: location.id)
    expect(response).to have_http_status(:ok)
  end

  it "sends people back to locations when no location is chosen" do
    sign_in guest
    get new_booking_path
    expect(response).to redirect_to(locations_path)
  end

  it "renders the edit page for the guest" do
    sign_in guest
    get edit_booking_path(booking)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Change Booking Times")
  end

  it "shows hosts the confirm and decline buttons on the bookings page" do
    sign_in host
    get bookings_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Confirm")
    expect(response.body).to include("Decline")
  end

  it "renders the location forms for the host" do
    sign_in host
    get new_location_path
    expect(response).to have_http_status(:ok)
    get edit_location_path(location)
    expect(response).to have_http_status(:ok)
  end

  it "renders the JSON views" do
    sign_in guest
    get bookings_path(format: :json)
    expect(response).to have_http_status(:ok)
    get location_path(location, format: :json)
    expect(response).to have_http_status(:ok)
  end
end
