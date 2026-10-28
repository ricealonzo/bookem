# Hosts set when guests can book: opening and closing times for each day of
# the week, and a slot length. Existing locations start out open Monday to
# Saturday, 9 AM to 5 PM, in 1-hour slots; hosts can change that.
class CreateOpeningHours < ActiveRecord::Migration[8.1]
  def up
    create_table :opening_hours do |t|
      t.bigint :location_id, null: false
      t.integer :weekday, null: false            # 0 = Sunday ... 6 = Saturday
      t.integer :opens_at_minute, null: false    # minutes after midnight
      t.integer :closes_at_minute, null: false   # up to 1440 (midnight)
      t.timestamps
    end
    add_index :opening_hours, [ :location_id, :weekday ], unique: true
    add_foreign_key :opening_hours, :locations, on_delete: :cascade

    add_column :locations, :slot_minutes, :integer, null: false, default: 60

    execute <<~SQL
      INSERT INTO opening_hours (location_id, weekday, opens_at_minute, closes_at_minute, created_at, updated_at)
      SELECT locations.id, days.weekday, 540, 1020, NOW(), NOW()
      FROM locations CROSS JOIN generate_series(1, 6) AS days(weekday)
    SQL
  end

  def down
    remove_column :locations, :slot_minutes
    drop_table :opening_hours
  end
end
