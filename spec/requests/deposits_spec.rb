require "rails_helper"

RSpec.describe "Deposits", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:host) { create_user(stripe_account_id: "acct_host", stripe_charges_enabled: true) }
  let(:guest) { create_user }
  let(:location) { create_location(host: host, slot_minutes: 60, deposit_percent: 50) }
  let!(:session_service) { location.services.create!(name: "Session", duration_minutes: 60, price_cents: 4000) }
  let(:start) { 4.days.from_now.change(hour: 10) }
  let(:checkout_url) { "https://checkout.stripe.com/c/pay/cs_test_1" }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("STRIPE_SECRET_KEY").and_return("sk_test_123")
    allow(ENV).to receive(:[]).with("STRIPE_WEBHOOK_SECRET").and_return("whsec_test")
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  after { WebMock.allow_net_connect! }

  def request_params
    { booking: { started_at: start.strftime("%Y-%m-%dT%H:%M"), ended_at: (start + 1.hour).strftime("%Y-%m-%dT%H:%M"),
                 location_id: location.id, service_id: session_service.id } }
  end

  def stub_checkout
    stub_request(:post, "https://api.stripe.com/v1/checkout/sessions")
      .to_return(status: 200, body: { id: "cs_test_1", url: checkout_url }.to_json)
  end

  def awaiting_booking(guest: self.guest)
    Booking.create!(location: location, guest: guest, service: session_service, started_at: start, ended_at: start + 1.hour)
      .tap { |booking| booking.update_columns(stripe_checkout_session_id: "cs_test_1") }
  end

  def paid_booking
    awaiting_booking.tap { |booking| booking.update_columns(payment_status: "paid", stripe_payment_intent_id: "pi_1") }
  end

  def stripe_event(type, object)
    payload = { type: type, data: { object: object } }.to_json
    signature = OpenSSL::HMAC.hexdigest("SHA256", "whsec_test", "#{Time.current.to_i}.#{payload}")
    post stripe_webhook_path, params: payload,
         headers: { "CONTENT_TYPE" => "application/json", "Stripe-Signature" => "t=#{Time.current.to_i},v1=#{signature}" }
  end

  describe "requesting a booking" do
    it "asks for the deposit and sends the guest to Stripe" do
      stub = stub_checkout
      sign_in guest
      post bookings_path, params: request_params

      expect(response).to redirect_to(checkout_url)
      booking = Booking.last
      expect(booking.deposit_cents).to eq(2000)
      expect(booking).to be_deposit_awaiting
      expect(booking.stripe_checkout_session_id).to eq("cs_test_1")
      expect(booking.payment_expires_at).to be_within(1.minute).of(35.minutes.from_now)

      expect(stub.with { |req|
        sent = Rack::Utils.parse_nested_query(req.body)
        sent.dig("payment_intent_data", "application_fee_amount") == "150" &&
          sent.dig("payment_intent_data", "transfer_data", "destination") == "acct_host" &&
          sent.dig("line_items", "0", "price_data", "unit_amount") == "2000"
      }).to have_been_requested
    end

    it "doesn't hold the time if Stripe can't start the payment" do
      stub_request(:post, "https://api.stripe.com/v1/checkout/sessions")
        .to_return(status: 500, body: { error: { message: "Stripe is down" } }.to_json)
      sign_in guest
      post bookings_path, params: request_params

      expect(Booking.last).to be_cancelled
      expect(response).to redirect_to(location_path(location, anchor: "availability"))
      expect(flash[:alert]).to include("haven't been charged")
    end

    it "skips the deposit when the host hasn't set up payouts" do
      host.update_column(:stripe_charges_enabled, false)
      sign_in guest
      post bookings_path, params: request_params

      booking = Booking.last
      expect(booking).to be_deposit_not_required
      expect(response).to redirect_to(booking_path(booking))
    end

    it "skips the deposit when Stripe isn't configured" do
      allow(ENV).to receive(:[]).with("STRIPE_SECRET_KEY").and_return(nil)
      sign_in guest
      post bookings_path, params: request_params

      expect(Booking.last).to be_deposit_not_required
    end
  end

  describe "the hold" do
    it "keeps the time for 35 minutes, then frees it if unpaid" do
      awaiting_booking
      rival = Booking.new(location: location, guest: create_user, service: session_service, started_at: start)
      expect(rival).not_to be_valid

      travel 36.minutes do
        expect(rival).to be_valid
      end
    end

    it "keeps unpaid requests away from the host" do
      booking = awaiting_booking
      sign_in host
      get bookings_path

      expect(response.body).not_to include(ActionView::RecordIdentifier.dom_id(booking))
      expect(booking).not_to be_respondable
    end
  end

  describe "Stripe's webhook" do
    it "marks the deposit paid" do
      booking = awaiting_booking
      stripe_event("checkout.session.completed", { id: "cs_test_1", payment_status: "paid", payment_intent: "pi_1" })

      expect(response).to have_http_status(:ok)
      booking.reload
      expect(booking).to be_deposit_paid
      expect(booking.stripe_payment_intent_id).to eq("pi_1")
      expect(booking).to be_respondable
    end

    it "releases the time when the payment page expires" do
      booking = awaiting_booking
      stripe_event("checkout.session.expired", { id: "cs_test_1", status: "expired", payment_status: "unpaid" })

      expect(booking.reload).to be_cancelled
      expect(booking).to be_deposit_expired
    end

    it "refuses requests without Stripe's signature" do
      booking = awaiting_booking
      post stripe_webhook_path,
           params: { type: "checkout.session.completed", data: { object: { id: "cs_test_1", payment_status: "paid" } } }.to_json,
           headers: { "CONTENT_TYPE" => "application/json", "Stripe-Signature" => "t=1,v1=forged" }

      expect(response).to have_http_status(:bad_request)
      expect(booking.reload).to be_deposit_awaiting
    end

    it "notes when a host's Stripe account is approved" do
      host.update_column(:stripe_charges_enabled, false)
      stripe_event("account.updated", { id: "acct_host", charges_enabled: true })

      expect(host.reload).to be_payouts_ready
    end

    it "refunds a payment that lands after the guest cancelled" do
      booking = awaiting_booking
      stub_request(:post, "https://api.stripe.com/v1/checkout/sessions/cs_test_1/expire").to_return(status: 400, body: { error: { message: "already complete" } }.to_json)
      refund = stub_request(:post, "https://api.stripe.com/v1/refunds").to_return(status: 200, body: { id: "re_1" }.to_json)
      sign_in guest
      patch cancel_booking_path(booking)

      stripe_event("checkout.session.completed", { id: "cs_test_1", payment_status: "paid", payment_intent: "pi_late" })

      expect(refund).to have_been_requested
      expect(booking.reload).to be_deposit_refunded
      expect(booking).to be_cancelled
    end
  end

  describe "coming back from Stripe" do
    it "checks the payment right away" do
      booking = awaiting_booking
      stub_request(:get, "https://api.stripe.com/v1/checkout/sessions/cs_test_1")
        .to_return(status: 200, body: { id: "cs_test_1", status: "complete", payment_status: "paid", payment_intent: "pi_1" }.to_json)
      sign_in guest
      get booking_path(booking, paid: 1)

      expect(booking.reload).to be_deposit_paid
      expect(response.body).to include("Waiting for the host")
    end
  end

  describe "refunds" do
    let!(:refund) do
      stub_request(:post, "https://api.stripe.com/v1/refunds").to_return(status: 200, body: { id: "re_1" }.to_json)
    end

    it "refunds the whole deposit when the host declines, and takes it back from the host" do
      booking = paid_booking
      sign_in host
      patch decline_booking_path(booking)

      expect(booking.reload).to be_deposit_refunded
      expect(flash[:notice]).to include("deposit was refunded")
      expect(refund.with { |req|
        sent = Rack::Utils.parse_nested_query(req.body)
        sent["payment_intent"] == "pi_1" && sent["reverse_transfer"] == "true" && sent["refund_application_fee"] == "true"
      }).to have_been_requested
    end

    it "refunds a guest who cancels at least 24 hours ahead" do
      booking = paid_booking
      sign_in guest
      patch cancel_booking_path(booking)

      expect(booking.reload).to be_deposit_refunded
    end

    it "keeps the deposit when the guest cancels within 24 hours" do
      booking = paid_booking
      travel_to(booking.started_at - 12.hours) do
        sign_in guest
        patch cancel_booking_path(booking)
      end

      expect(refund).not_to have_been_requested
      expect(booking.reload).to be_deposit_paid
      expect(booking).to be_cancelled
      expect(flash[:notice]).to include("isn't refunded")
    end

    it "always refunds when the host cancels" do
      booking = paid_booking
      booking.update!(status: :confirmed)
      travel_to(booking.started_at - 2.hours) do
        sign_in host
        patch cancel_booking_path(booking)
      end

      expect(booking.reload).to be_deposit_refunded
    end
  end

  describe "host payouts" do
    let(:new_host) { create_user }

    it "creates a Stripe account and sends the host to Stripe's setup pages" do
      stub_request(:post, "https://api.stripe.com/v1/accounts").to_return(status: 200, body: { id: "acct_new" }.to_json)
      stub_request(:post, "https://api.stripe.com/v1/account_links")
        .to_return(status: 200, body: { url: "https://connect.stripe.com/setup/e/acct_new/abc" }.to_json)
      sign_in new_host
      post connect_payouts_path

      expect(response).to redirect_to("https://connect.stripe.com/setup/e/acct_new/abc")
      expect(new_host.reload.stripe_account_id).to eq("acct_new")
    end

    it "checks the account when the host comes back" do
      new_host.update_column(:stripe_account_id, "acct_new")
      stub_request(:get, "https://api.stripe.com/v1/accounts/acct_new")
        .to_return(status: 200, body: { id: "acct_new", charges_enabled: true }.to_json)
      sign_in new_host
      get done_payouts_path

      expect(new_host.reload).to be_payouts_ready
      expect(flash[:notice]).to include("Payouts are set up")
    end

    it "shows the payouts page" do
      sign_in new_host
      get payouts_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Set up payouts with Stripe")
    end
  end
end
