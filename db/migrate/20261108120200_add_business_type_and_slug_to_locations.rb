# - business_type: which preset a location started from ("barbershop",
#   "recording_studio", ...). Decides the starter services and the wording.
# - slug: the short public booking link, /b/riverside-barbershop, for an
#   Instagram bio or a business card.
#
# Existing locations get a slug from their name plus their id, which is
# always unique. Hosts can change it on the edit page.
class AddBusinessTypeAndSlugToLocations < ActiveRecord::Migration[8.1]
  def up
    add_column :locations, :business_type, :string, null: false, default: "other"
    add_column :locations, :slug, :string
    add_index :locations, :slug, unique: true

    execute <<~SQL
      UPDATE locations
      SET slug = trim(both '-' from lower(regexp_replace(coalesce(name, 'location'), '[^a-zA-Z0-9]+', '-', 'g'))) || '-' || id
    SQL
  end

  def down
    remove_column :locations, :slug
    remove_column :locations, :business_type
  end
end
