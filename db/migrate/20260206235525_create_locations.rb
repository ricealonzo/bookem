class CreateLocations < ActiveRecord::Migration[8.0]
  def change
    create_table :locations do |t|
      t.string :name
      t.string :description
      t.string :address
      t.string :city
      t.string :state
      t.string :postal_code
      t.integer :host_id

      t.timestamps
    end
  end
end
