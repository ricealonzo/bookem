require "rails_helper"

# Every page renders for the people who can see it.
RSpec.describe "Pages", type: :request do
  let(:host) { create_user }
  let(:guest) { create_user }
  let(:location) { create_location(host: host) }
  let!(:booking) { create_booking(location: location, guest: guest) }

  it "shows signed-in guests selectable slots and the request form" do
    sign_in guest
    get location_path(location)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Request Booking")
    expect(response.body).to include("booking-picker#toggleSlot")
  end

  it "shows hosts their hours and who booked, without a request form" do
    sign_in host
    get location_path(location, start_date: booking.started_at.to_date)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Your Location")
    expect(response.body).not_to include("Request Booking")
    expect(response.body).to include("Requested: #{guest.first_name}")
  end

  it "shows visitors the time slots but asks them to log in to book" do
    get location_path(location)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("slot-list")
    expect(response.body).not_to include("booking-picker#toggleSlot")
    expect(response.body).to include("to request a booking")
  end

  it "sends people back to locations when no location is chosen" do
    sign_in guest
    get new_booking_path
    expect(response).to redirect_to(locations_path)
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
