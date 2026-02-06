class CreateBookings < ActiveRecord::Migration[8.0]
  def change
    create_table :bookings do |t|
      t.string :started_at
      t.string :ended_at
      t.integer :guest_id
      t.integer :location_id

      t.timestamps
    end
  end
end
