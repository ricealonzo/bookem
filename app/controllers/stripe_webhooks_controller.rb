# Stripe calls this URL when something happens: a deposit is paid, a payment
# page expires, or a host's account is approved.
#
# It inherits from ActionController::API, which has no sessions, cookies or
# CSRF tokens. Instead, every request must carry Stripe's signature, which
# proves it came from Stripe and wasn't changed on the way.
class StripeWebhooksController < ActionController::API
  CHECKOUT_EVENTS = %w[
    checkout.session.completed
    checkout.session.async_payment_succeeded
    checkout.session.expired
  ].freeze

  # POST /stripe/webhook
  def create
    payload = request.raw_post
    signature = request.headers["Stripe-Signature"]
    return head :bad_request unless signed_by_stripe?(payload, signature)

    event = JSON.parse(payload)
    object = event.dig("data", "object") || {}

    case event["type"]
    when *CHECKOUT_EVENTS
      booking = Booking.find_by(stripe_checkout_session_id: object["id"])
      Deposits.record_session!(booking, object) if booking
    when "account.updated"
      user = User.find_by(stripe_account_id: object["id"])
      user&.update_column(:stripe_charges_enabled, object["charges_enabled"] == true)
    end

    head :ok
  rescue JSON::ParserError
    head :bad_request
  end

  private

  # Platform events and connected-account events come from two Stripe
  # webhook endpoints, each with its own secret.
  def signed_by_stripe?(payload, signature)
    [ ENV["STRIPE_WEBHOOK_SECRET"], ENV["STRIPE_CONNECT_WEBHOOK_SECRET"] ].compact_blank.any? do |secret|
      StripeApi.valid_signature?(payload, signature, secret: secret)
    end
  end
end
