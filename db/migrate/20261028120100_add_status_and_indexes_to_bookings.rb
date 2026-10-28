# Adds a status so hosts can confirm or decline booking requests, plus indexes
# for the queries the app runs most (a location's bookings by time, a guest's
# bookings, a host's locations). Existing bookings count as confirmed.
class AddStatusAndIndexesToBookings < ActiveRecord::Migration[8.0]
  def change
    add_column :bookings, :status, :string, null: false, default: "pending"
    up_only { execute "UPDATE bookings SET status = 'confirmed'" }

    add_index :bookings, [ :location_id, :started_at ]
    add_index :bookings, :guest_id
    add_index :locations, :host_id
  end
end
