require "rails_helper"

RSpec.describe "Bookings", type: :request do
  let(:host) { create_user }
  let(:guest) { create_user }
  let(:stranger) { create_user }
  let(:location) { create_location(host: host) }
  let(:start) { 4.days.from_now.change(hour: 9) }

  def booking_params(starts: start, ends: start + 2.hours, **extra)
    { booking: { started_at: starts.strftime("%Y-%m-%dT%H:%M"), ended_at: ends.strftime("%Y-%m-%dT%H:%M"), location_id: location.id, **extra } }
  end

  describe "requesting a booking" do
    it "requires signing in" do
      expect { post bookings_path, params: booking_params }.not_to change(Booking, :count)
      expect(response).to redirect_to(new_user_session_path)
    end

    it "creates a pending booking for the signed-in guest" do
      sign_in guest
      expect { post bookings_path, params: booking_params }.to change(Booking, :count).by(1)

      booking = Booking.last
      expect(booking.guest).to eq(guest)
      expect(booking).to be_pending
      expect(response).to redirect_to(booking_path(booking))
    end

    it "ignores a guest_id sent in the form" do
      sign_in guest
      post bookings_path, params: booking_params(guest_id: stranger.id)
      expect(Booking.last.guest).to eq(guest)
    end

    it "refuses a time that's already booked" do
      create_booking(location: location, guest: stranger, starts: start, hours: 3)
      sign_in guest

      expect { post bookings_path, params: booking_params(starts: start + 1.hour, ends: start + 2.hours) }
        .not_to change(Booking, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("overlaps another booking")
    end

    it "doesn't let hosts book their own location" do
      sign_in host
      expect { post bookings_path, params: booking_params }.not_to change(Booking, :count)
    end
  end

  describe "privacy" do
    let!(:booking) { create_booking(location: location, guest: guest) }

    it "shows a booking to its guest and host only" do
      sign_in guest
      get booking_path(booking)
      expect(response).to have_http_status(:ok)

      sign_in host
      get booking_path(booking)
      expect(response).to have_http_status(:ok)

      sign_in stranger
      get booking_path(booking)
      expect(response).to redirect_to(root_path)
    end

    it "lists only the user's own trips and requests" do
      someone_elses = create_booking(location: create_location(name: "Elsewhere Hall"), guest: stranger)

      sign_in guest
      get bookings_path
      expect(response.body).to include(location.name)
      expect(response.body).not_to include("Elsewhere Hall")
      expect(someone_elses).to be_persisted
    end
  end

  describe "host responses" do
    let!(:booking) { create_booking(location: location, guest: guest) }

    it "lets the host confirm" do
      sign_in host
      patch confirm_booking_path(booking)
      expect(booking.reload).to be_confirmed
    end

    it "lets the host decline" do
      sign_in host
      patch decline_booking_path(booking)
      expect(booking.reload).to be_declined
    end

    it "doesn't let the guest confirm their own request" do
      sign_in guest
      patch confirm_booking_path(booking)
      expect(booking.reload).to be_pending
    end

    it "doesn't let strangers decline" do
      sign_in stranger
      patch decline_booking_path(booking)
      expect(booking.reload).to be_pending
    end
  end

  describe "changing and cancelling" do
    let!(:booking) { create_booking(location: location, guest: guest, starts: start) }

    it "lets the guest change times while pending" do
      sign_in guest
      patch booking_path(booking), params: booking_params(starts: start + 1.day, ends: start + 1.day + 1.hour)
      expect(booking.reload.started_at).to be_within(1.minute).of(start + 1.day)
    end

    it "doesn't let the guest move the booking to another location" do
      other = create_location
      sign_in guest
      patch booking_path(booking), params: { booking: { location_id: other.id } }
      expect(booking.reload.location).to eq(location)
    end

    it "doesn't let the host change the guest's times" do
      sign_in host
      patch booking_path(booking), params: booking_params(starts: start + 1.day, ends: start + 1.day + 1.hour)
      expect(booking.reload.started_at).to be_within(1.minute).of(start)
    end

    it "lets the guest cancel" do
      sign_in guest
      patch cancel_booking_path(booking)
      expect(booking.reload).to be_cancelled
    end

    it "doesn't let strangers cancel" do
      sign_in stranger
      patch cancel_booking_path(booking)
      expect(booking.reload).to be_pending
    end

    it "has no delete route, so both sides keep a record" do
      expect { Rails.application.routes.recognize_path(booking_path(booking), method: :delete) }
        .to raise_error(ActionController::RoutingError)
    end
  end
end
