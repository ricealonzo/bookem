# Hosts connect a Stripe account here so deposits are paid out to their bank.
#
# Stripe Connect Express does the hard parts (identity checks, bank details,
# tax forms) on Stripe's own pages. Bookem only stores the account id and
# whether the account can take payments yet.
class PayoutsController < ApplicationController
  before_action :authenticate_user!

  # GET /payouts
  def show
    @stripe_enabled = StripeApi.enabled?
  end

  # POST /payouts/connect
  # Creates the host's Stripe account the first time, then sends them to
  # Stripe's onboarding pages.
  def connect
    user = current_user
    if user.stripe_account_id.blank?
      account = StripeApi.post("/v1/accounts", {
        type: "express",
        country: "US",
        email: user.email,
        capabilities: { card_payments: { requested: true }, transfers: { requested: true } },
        metadata: { bookem_user_id: user.id }
      }, idempotency_key: "bookem-account-#{user.id}")
      user.update_column(:stripe_account_id, account["id"])
    end

    link = StripeApi.post("/v1/account_links", {
      account: user.stripe_account_id,
      refresh_url: refresh_payouts_url,
      return_url: done_payouts_url,
      type: "account_onboarding"
    })
    redirect_to link["url"], allow_other_host: true, status: :see_other
  rescue StripeApi::Error => e
    redirect_to payouts_path, alert: "Couldn't reach Stripe: #{e.message}", status: :see_other
  end

  # GET /payouts/done
  # Stripe sends the host back here. Check whether the account is ready.
  def done
    if current_user.stripe_account_id.present?
      account = StripeApi.get("/v1/accounts/#{current_user.stripe_account_id}")
      current_user.update_column(:stripe_charges_enabled, account["charges_enabled"] == true)
    end

    if current_user.payouts_ready?
      redirect_to payouts_path, notice: "Payouts are set up. You can now ask for deposits on your locations."
    else
      redirect_to payouts_path, alert: "Stripe still needs a few details before you can take deposits."
    end
  rescue StripeApi::Error => e
    redirect_to payouts_path, alert: "Couldn't check your Stripe account: #{e.message}"
  end

  # GET /payouts/refresh
  # Stripe sends the host here when an onboarding link has expired.
  def refresh
    redirect_to payouts_path, alert: "That Stripe link expired. Choose \"Continue setup\" to get a new one."
  end
end
