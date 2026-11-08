require "net/http"

# A small client for the parts of Stripe's API that Bookem uses. It talks to
# https://api.stripe.com directly with Net::HTTP, so there's no extra gem.
#
#   StripeApi.post("/v1/refunds", { payment_intent: "pi_123" })
#   StripeApi.get("/v1/accounts/acct_123")
#
# Payments are switched on by setting STRIPE_SECRET_KEY. Without it,
# StripeApi.enabled? is false and Bookem works exactly as before (no deposits).
module StripeApi
  BASE_URL = "https://api.stripe.com".freeze

  class Error < StandardError; end

  def self.enabled?
    secret_key.present?
  end

  def self.secret_key
    ENV["STRIPE_SECRET_KEY"].presence
  end

  def self.webhook_secret
    ENV["STRIPE_WEBHOOK_SECRET"].presence
  end

  def self.get(path)
    request(Net::HTTP::Get.new(path))
  end

  # Stripe takes form-encoded parameters, with nested ones written like
  # line_items[0][price_data][currency]=usd. Rack builds that from a hash.
  # The idempotency key makes a retried request safe: Stripe does it once.
  def self.post(path, params = {}, idempotency_key: nil)
    req = Net::HTTP::Post.new(path)
    req["Content-Type"] = "application/x-www-form-urlencoded"
    req["Idempotency-Key"] = idempotency_key if idempotency_key
    req.body = Rack::Utils.build_nested_query(params)
    request(req)
  end

  def self.request(req)
    raise Error, "Stripe isn't set up (STRIPE_SECRET_KEY is missing)" unless enabled?

    req["Authorization"] = "Bearer #{secret_key}"
    uri = URI(BASE_URL)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 20) do |http|
      http.request(req)
    end

    body = JSON.parse(response.body.presence || "{}")
    return body if response.is_a?(Net::HTTPSuccess)

    raise Error, body.dig("error", "message") || "Stripe returned #{response.code}"
  rescue JSON::ParserError, SocketError, Timeout::Error, Errno::ECONNREFUSED, OpenSSL::SSL::SSLError => e
    raise Error, "Couldn't reach Stripe: #{e.message}"
  end

  # Checks that a webhook really came from Stripe. Stripe signs
  # "timestamp.body" with the webhook secret (HMAC-SHA256) and sends
  #   Stripe-Signature: t=1700000000,v1=5257a869...
  # Old timestamps are refused so a captured request can't be replayed.
  def self.valid_signature?(payload, header, secret: webhook_secret, tolerance: 5.minutes, now: Time.current)
    return false if secret.blank? || header.blank?

    parts = header.split(",").map { |part| part.split("=", 2) }
    timestamp = parts.find { |key, _| key == "t" }&.last.to_i
    signatures = parts.select { |key, _| key == "v1" }.map(&:last)
    return false if timestamp.zero? || signatures.empty?
    return false if (now.to_i - timestamp).abs > tolerance.to_i

    expected = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{payload}")
    signatures.any? { |signature| ActiveSupport::SecurityUtils.secure_compare(signature, expected) }
  end
end
