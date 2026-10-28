require "rails_helper"

RSpec.describe "Forgery protection", type: :request do
  around do |example|
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  it "rejects form posts that don't carry the page's security token" do
    guest = create_user
    location = create_location
    sign_in guest

    starts = 3.days.from_now.change(hour: 9)
    expect {
      post bookings_path, params: {
        booking: { started_at: starts.iso8601, ended_at: (starts + 1.hour).iso8601, location_id: location.id }
      }
    }.not_to change(Booking, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
