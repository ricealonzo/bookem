# Deposits through Stripe.
#
# - Hosts connect a Stripe account (Stripe Connect Express) so deposits are
#   paid out to their bank. Bookem keeps a small platform fee.
# - Each location can ask for a deposit: none, 25%, 50% or the full price.
# - A booking that needs a deposit holds its time for 35 minutes while the
#   guest pays. Paid deposits are refunded when the host declines or cancels,
#   or when the guest cancels at least 24 hours ahead.
class AddDeposits < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :stripe_account_id, :string
    add_column :users, :stripe_charges_enabled, :boolean, null: false, default: false
    add_index :users, :stripe_account_id, unique: true

    add_column :locations, :deposit_percent, :integer, null: false, default: 0

    add_column :bookings, :deposit_cents, :integer, null: false, default: 0
    add_column :bookings, :payment_status, :string, null: false, default: "not_required"
    add_column :bookings, :payment_expires_at, :datetime
    add_column :bookings, :stripe_checkout_session_id, :string
    add_column :bookings, :stripe_payment_intent_id, :string
    add_index :bookings, :stripe_checkout_session_id, unique: true
  end
end
