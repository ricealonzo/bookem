# One engine for many kinds of business.
#
# - A resource is the thing that actually gets booked: a room, a chair, a
#   barber, a stylist. A location can have several, so a shop with three
#   barbers can take three bookings at the same time.
# - A service is what the guest is buying: "Fade, 45 min, $35" or
#   "Mix & master, 2 hours, $150". Its length decides the booking's length.
#
# Every existing location gets one resource, "Main space", and its bookings
# are moved onto it, so nothing changes for locations that don't use this.
class CreateResourcesAndServices < ActiveRecord::Migration[8.1]
  def up
    create_table :resources do |t|
      t.bigint :location_id, null: false
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :resources, [ :location_id, :position ]
    add_foreign_key :resources, :locations, on_delete: :cascade

    create_table :services do |t|
      t.bigint :location_id, null: false
      t.string :name, null: false
      t.string :description
      t.integer :duration_minutes, null: false
      t.integer :price_cents, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :services, :location_id
    add_foreign_key :services, :locations, on_delete: :cascade

    # What hosts call their resources ("Room", "Barber", "Chair"), and the
    # price of one slot for bookings that don't use a service.
    add_column :locations, :resource_label, :string, null: false, default: "Room"
    add_column :locations, :slot_price_cents, :integer, null: false, default: 0

    add_column :bookings, :resource_id, :bigint
    add_column :bookings, :service_id, :bigint
    # The price when the booking was made, so later price changes don't
    # rewrite old bookings.
    add_column :bookings, :price_cents, :integer, null: false, default: 0
    add_index :bookings, [ :resource_id, :started_at ]
    add_index :bookings, :service_id
    add_foreign_key :bookings, :resources
    add_foreign_key :bookings, :services, on_delete: :nullify

    execute <<~SQL
      INSERT INTO resources (location_id, name, active, position, created_at, updated_at)
      SELECT id, 'Main space', TRUE, 0, NOW(), NOW() FROM locations
    SQL

    execute <<~SQL
      UPDATE bookings SET resource_id = resources.id
      FROM resources
      WHERE resources.location_id = bookings.location_id
    SQL
  end

  def down
    remove_foreign_key :bookings, :services
    remove_foreign_key :bookings, :resources
    remove_column :bookings, :price_cents
    remove_column :bookings, :service_id
    remove_column :bookings, :resource_id
    remove_column :locations, :slot_price_cents
    remove_column :locations, :resource_label
    drop_table :services
    drop_table :resources
  end
end
