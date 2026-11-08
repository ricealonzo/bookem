# Lesson 2: Taking deposits with Stripe

**Branch:** `stripe-deposits` (built on top of `services-and-resources`)
**Why it matters:** This is the feature business owners pay for. A no-show costs a barber a whole slot of income. A deposit fixes that, and every deposit pays Bookem a small fee. It's also how Bookem earns money without charging hosts a monthly bill up front.

## How the money moves

Bookem uses **Stripe Connect** with **destination charges**:

```
Guest pays $20 deposit
        │
        ▼
Bookem's Stripe account ───────────► Host's Stripe account: $18.50 ──► host's bank
        │
        └── Bookem keeps the platform fee: 5% + 50¢ = $1.50
            (and pays Stripe's card fee out of it, about 88¢)
```

- Each host connects **their own** Stripe account once. Stripe checks their identity and bank details on Stripe's own pages, so Bookem never touches bank numbers.
- With destination charges, **the platform pays Stripe's card fee**. That's why the fee is a percent **plus** a fixed amount: a flat 5% on a $20 deposit ($1.00) barely covers Stripe's ~88¢. Change it with `PLATFORM_FEE_PERCENT` and `PLATFORM_FEE_FIXED_CENTS`.
- Stripe doesn't give back its card fee when you refund, so every refunded deposit costs Bookem that fee. Keep that in mind when you price.

## The booking's life with a deposit

```
guest picks a time
   │
   ▼
pending + awaiting ──(pays within 35 min)──► pending + paid ──► host confirms ──► confirmed + paid
   │                                              │
   │                                              └─ host declines ──► declined + refunded
   └──(doesn't pay)──► cancelled + expired   (the time is free again)
```

Two separate fields: `status` (the host's answer) and `payment_status` (the money). Keeping them apart means the existing confirm/decline/cancel code didn't need rewriting. It only needed a few extra checks.

## What changed, file by file

### 1. `app/services/stripe_api.rb`: talking to Stripe without a gem

Most apps use the `stripe` gem. Bookem calls Stripe's HTTP API directly with Ruby's built-in `Net::HTTP`, which shows you what the gem does underneath:

- Every request sends `Authorization: Bearer sk_test_...`.
- Stripe takes **form-encoded** parameters. Nested ones look like `line_items[0][price_data][currency]=usd`, and `Rack::Utils.build_nested_query` builds that from a Ruby hash.
- `Idempotency-Key` makes retries safe. If the refund request times out and Bookem sends it again with the same key, Stripe refunds once. This is how payment systems avoid charging or refunding twice.

**Webhook signatures** (`StripeApi.valid_signature?`): Stripe calls Bookem's `/stripe/webhook` URL when a payment finishes. Anyone on the internet could POST to that URL pretending to be Stripe, so Stripe signs each request:

```ruby
expected = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{payload}")
```

Only Stripe and Bookem know the secret, so only they can make a matching signature. The timestamp is checked too (5-minute window), so an attacker can't record a real request and send it again later. `secure_compare` compares in constant time, so the response time doesn't leak how many characters matched.

### 2. `app/services/deposits.rb`: the rules in one place

- `amount_for(booking)`: price × the location's deposit percent. Under 50¢ means no deposit (Stripe's minimum).
- `start_checkout!`: creates a Stripe **Checkout Session**, a payment page hosted by Stripe. Bookem never sees card numbers, which keeps it out of most PCI (card security) rules.
- `record_session!` / `record_payment!`: marks the deposit paid. It also handles two rare race conditions: the guest cancelled but paid anyway, or the hold ran out and someone else took the time. In both cases the guest is refunded automatically.
- `refund!`: refunds with `reverse_transfer: true` (pull the money back from the host) and `refund_application_fee: true` (Bookem gives its fee back too).

### 3. The 35-minute hold: `app/models/booking.rb`

While the guest is on Stripe's page, nobody else should grab their time. But if they wander off, the time can't be blocked forever. The `active` scope handles both:

```ruby
scope :active, lambda {
  where(status: ACTIVE_STATUSES)
    .where("bookings.payment_status <> 'awaiting' OR bookings.payment_expires_at > ?", Time.current)
}
```

No background job is needed to release the time. The moment `payment_expires_at` passes, the query stops counting that booking. This is a **lazy expiry**. Stripe's `checkout.session.expired` webhook tidies the record up afterwards.

The enum uses `prefix: :deposit`, so the methods read clearly: `deposit_paid?`, `deposit_awaiting?`, `deposit_refunded?`.

### 4. Two ways to learn a payment succeeded

1. **Webhook** (`StripeWebhooksController`): Stripe calls Bookem. Reliable, but it can arrive a few seconds late.
2. **Return trip** (`BookingsController#show` with `?paid=1`): when the guest lands back on Bookem, it asks Stripe directly.

Whichever happens first wins, and the second one does nothing because the deposit is already marked paid. Code that's safe to run twice is called **idempotent**.

`StripeWebhooksController` inherits from `ActionController::API`, not `ApplicationController`. Stripe doesn't have a session cookie or a CSRF token, so the signature check replaces both.

### 5. Host onboarding: `PayoutsController`

1. `connect`: creates an Express account (`POST /v1/accounts`) the first time, then an **account link** (`POST /v1/account_links`), a one-time URL to Stripe's setup pages.
2. Stripe sends the host back to `done`, which reads `charges_enabled` from Stripe.
3. `account.updated` webhooks keep that up to date if Stripe approves the account later.

Deposits only switch on when all three are true: `STRIPE_SECRET_KEY` is set, the host's account can take charges, and the location asks for a deposit (`Location#collects_deposits?`). If any is missing, booking works exactly as before.

### 6. Tests without touching Stripe: `spec/requests/deposits_spec.rb`

**WebMock** intercepts HTTP calls in tests. `stub_request(:post, "https://api.stripe.com/v1/refunds")` returns a fake answer, and `have_been_requested` checks Bookem really called it with the right parameters, like `reverse_transfer=true`. `travel_to` moves the clock to test the 35-minute hold and the 24-hour refund window.

## Try it with Stripe's test mode

1. Create a free Stripe account and stay in **Test mode**.
2. In the Dashboard, turn on **Connect** (choose "Platform or marketplace").
3. Copy the test secret key (`sk_test_...`) into `STRIPE_SECRET_KEY`.
4. Install the Stripe CLI and forward webhooks to your laptop:
   ```bash
   stripe listen --forward-to localhost:3000/stripe/webhook
   ```
   It prints a `whsec_...` secret. Put it in `STRIPE_WEBHOOK_SECRET`.
5. Sign in as a host, open **Payouts**, and connect a test account (Stripe's test pages accept fake details).
6. Set a location's deposit to 50%, sign in as a guest, and pay with card `4242 4242 4242 4242`, any future date, any CVC.
7. Decline the booking as the host and watch the refund appear in the Stripe Dashboard.

```bash
bundle exec rspec spec/services/stripe_api_spec.rb spec/requests/deposits_spec.rb
```

## Check your understanding

1. Why is the payment status a separate field from the booking status?
2. What stops someone from POSTing a fake "payment succeeded" event to `/stripe/webhook`?
3. A guest's Wi-Fi drops right after paying, so they never come back to Bookem. How does the booking still get marked paid?
4. Why does the refund use an idempotency key based on the booking id?
5. Work out Bookem's profit on a $40 deposit at 5% + 50¢, if Stripe charges 2.9% + 30¢.

## How to talk about it in an interview

> "I added deposits with Stripe Connect destination charges, calling Stripe's REST API directly. Webhooks are verified with HMAC signatures and a timestamp window, requests use idempotency keys, and payment confirmation is idempotent, so the webhook and the return redirect can't double-process. Unpaid holds expire lazily through the query scope instead of a background job, and every money path, including the race where a guest pays after cancelling, has a request spec with WebMock."
