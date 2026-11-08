require "rails_helper"

RSpec.describe StripeApi do
  describe ".valid_signature?" do
    let(:secret) { "whsec_test" }
    let(:payload) { %({"type":"checkout.session.completed"}) }
    let(:now) { Time.current }

    def header_for(body, at: now, key: secret)
      signature = OpenSSL::HMAC.hexdigest("SHA256", key, "#{at.to_i}.#{body}")
      "t=#{at.to_i},v1=#{signature}"
    end

    it "accepts a request signed with the secret" do
      expect(StripeApi.valid_signature?(payload, header_for(payload), secret: secret, now: now)).to be(true)
    end

    it "rejects a body that was changed after signing" do
      header = header_for(payload)
      expect(StripeApi.valid_signature?(payload.sub("completed", "expired"), header, secret: secret, now: now)).to be(false)
    end

    it "rejects a signature made with another secret" do
      expect(StripeApi.valid_signature?(payload, header_for(payload, key: "whsec_other"), secret: secret, now: now)).to be(false)
    end

    it "rejects an old request so it can't be replayed" do
      header = header_for(payload, at: now - 10.minutes)
      expect(StripeApi.valid_signature?(payload, header, secret: secret, now: now)).to be(false)
    end

    it "rejects everything when no secret is set" do
      expect(StripeApi.valid_signature?(payload, header_for(payload), secret: nil, now: now)).to be(false)
    end
  end

  describe "requests" do
    before do
      allow(ENV).to receive(:[]).and_call_original
      WebMock.disable_net_connect!(allow_localhost: true)
    end

    after { WebMock.allow_net_connect! }

    it "refuses to call Stripe without a secret key" do
      allow(ENV).to receive(:[]).with("STRIPE_SECRET_KEY").and_return(nil)
      expect { StripeApi.get("/v1/balance") }.to raise_error(StripeApi::Error, /STRIPE_SECRET_KEY/)
    end

    it "sends form-encoded nested parameters with the secret key" do
      allow(ENV).to receive(:[]).with("STRIPE_SECRET_KEY").and_return("sk_test_123")
      # Rack reads line_items[0][quantity] back the way Stripe does.
      stub = stub_request(:post, "https://api.stripe.com/v1/things")
        .with(headers: { "Authorization" => "Bearer sk_test_123", "Idempotency-Key" => "key-1" }) { |req|
          Rack::Utils.parse_nested_query(req.body) == { "line_items" => { "0" => { "quantity" => "1" } } }
        }
        .to_return(status: 200, body: { id: "thing_1" }.to_json)

      result = StripeApi.post("/v1/things", { line_items: { "0" => { quantity: 1 } } }, idempotency_key: "key-1")

      expect(stub).to have_been_requested
      expect(result["id"]).to eq("thing_1")
    end

    it "turns Stripe's error message into a StripeApi::Error" do
      allow(ENV).to receive(:[]).with("STRIPE_SECRET_KEY").and_return("sk_test_123")
      stub_request(:get, "https://api.stripe.com/v1/accounts/acct_x")
        .to_return(status: 404, body: { error: { message: "No such account" } }.to_json)

      expect { StripeApi.get("/v1/accounts/acct_x") }.to raise_error(StripeApi::Error, "No such account")
    end
  end
end
