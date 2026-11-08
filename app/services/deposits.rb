# Deposits: the money side of a booking.
#
# How the money moves (Stripe Connect "destination charges"):
#
#   guest pays $20 deposit ──► Bookem's Stripe account ──► host's Stripe account ($19)
#                                      └── Bookem keeps the platform fee ($1)
#
# Each host connects their own Stripe account once (see PayoutsController),
# so deposits land in their bank and Bookem never holds their money.
module Deposits
  # Choices a host has for a location's deposit.
  PERCENTS = [ 0, 25, 50, 100 ].freeze

  # How long a booking holds its time while the guest pays. Stripe's
  # Checkout pages must stay open at least 30 minutes.
  HOLD = 35.minutes

  # Guests who cancel at least this far ahead get their deposit back.
  FREE_CANCELLATION = 24.hours

  # Stripe won't take a card payment under 50 cents.
  MINIMUM_CENTS = 50

  # Bookem's cut of each deposit: a percent plus a fixed amount. With
  # destination charges Bookem pays Stripe's card fees (about 2.9% + 30¢),
  # so the fee has to cover those first. Change it with PLATFORM_FEE_PERCENT
  # and PLATFORM_FEE_FIXED_CENTS.
  def self.platform_fee_percent
    ENV.fetch("PLATFORM_FEE_PERCENT", "5").to_f
  end

  def self.platform_fee_fixed_cents
    ENV.fetch("PLATFORM_FEE_FIXED_CENTS", "50").to_i
  end

  # Never the whole deposit: the host always gets something.
  def self.platform_fee_for(cents)
    fee = (cents * platform_fee_percent / 100.0).round + platform_fee_fixed_cents
    fee.clamp(0, [ cents - 1, 0 ].max)
  end

  # The deposit a new booking needs, in cents. 0 means none.
  def self.amount_for(booking)
    location = booking.location
    return 0 unless location&.collects_deposits?

    cents = (booking.price_cents.to_i * location.deposit_percent / 100.0).round
    cents >= MINIMUM_CENTS ? cents : 0
  end

  # Opens a Stripe Checkout page for the deposit and returns its URL. The
  # page closes when the booking's hold runs out.
  def self.start_checkout!(booking, success_url:, cancel_url:)
    location = booking.location
    session = StripeApi.post("/v1/checkout/sessions", {
      mode: "payment",
      client_reference_id: booking.id,
      customer_email: booking.guest.email,
      success_url: success_url,
      cancel_url: cancel_url,
      expires_at: booking.payment_expires_at.to_i,
      metadata: { booking_id: booking.id },
      line_items: {
        "0" => {
          quantity: 1,
          price_data: {
            currency: "usd",
            unit_amount: booking.deposit_cents,
            product_data: { name: "Deposit: #{booking.service&.name || "Booking"} at #{location.name}" }
          }
        }
      },
      payment_intent_data: {
        application_fee_amount: platform_fee_for(booking.deposit_cents),
        transfer_data: { destination: location.host.stripe_account_id },
        metadata: { booking_id: booking.id }
      }
    }, idempotency_key: "bookem-checkout-#{booking.id}")

    booking.update!(stripe_checkout_session_id: session["id"])
    session["url"]
  end

  # Asks Stripe whether the guest has paid. Used when the guest comes back
  # from Checkout, in case the webhook hasn't arrived yet.
  def self.sync!(booking)
    return booking unless booking.deposit_awaiting? && booking.stripe_checkout_session_id.present?

    session = StripeApi.get("/v1/checkout/sessions/#{booking.stripe_checkout_session_id}")
    record_session!(booking, session)
  end

  # Records what a Checkout session says: paid, or expired.
  def self.record_session!(booking, session)
    if session["payment_status"] == "paid"
      record_payment!(booking, session["payment_intent"])
    elsif session["status"] == "expired" && booking.deposit_awaiting?
      booking.update!(status: :cancelled, payment_status: :expired)
    end
    booking
  end

  # Marks the deposit paid. In the rare cases where the booking was
  # cancelled first, or the hold ran out and someone else took the time
  # before the payment landed, the guest is refunded.
  def self.record_payment!(booking, payment_intent_id)
    return if booking.deposit_paid? || booking.deposit_refunded?

    still_wanted = Booking::ACTIVE_STATUSES.include?(booking.status)
    booking.stripe_payment_intent_id = payment_intent_id
    booking.payment_status = :paid
    return if still_wanted && booking.save

    booking.update_columns(payment_status: "paid", stripe_payment_intent_id: payment_intent_id, updated_at: Time.current)
    refund!(booking)
    booking.update_columns(status: "cancelled") if still_wanted
  end

  # Closes the Stripe page for a deposit that's no longer wanted, so it
  # can't be paid after the guest cancels.
  def self.close_checkout!(booking)
    return unless booking.deposit_awaiting?

    if booking.stripe_checkout_session_id.present?
      StripeApi.post("/v1/checkout/sessions/#{booking.stripe_checkout_session_id}/expire")
    end
    booking.update_columns(payment_status: "expired", updated_at: Time.current)
  rescue StripeApi::Error => e
    # Already expired or completed. If it was paid, the webhook refunds it.
    Rails.logger.info("Couldn't close checkout for booking #{booking.id}: #{e.message}")
    booking.update_columns(payment_status: "expired", updated_at: Time.current)
  end

  # Refunds the whole deposit. The money comes back out of the host's
  # Stripe account (reverse_transfer) and Bookem returns its fee too.
  # The idempotency key means a double-click can't refund twice.
  def self.refund!(booking)
    return false unless booking.deposit_paid? && booking.stripe_payment_intent_id.present?

    StripeApi.post("/v1/refunds", {
      payment_intent: booking.stripe_payment_intent_id,
      reverse_transfer: true,
      refund_application_fee: true,
      metadata: { booking_id: booking.id }
    }, idempotency_key: "bookem-refund-#{booking.id}")

    booking.update_columns(payment_status: "refunded", updated_at: Time.current)
    true
  end

  # Hosts who cancel always refund. Guests get it back if they cancel early.
  def self.refund_on_cancel?(booking, by_host:)
    by_host || booking.started_at - Time.current >= FREE_CANCELLATION
  end
end
