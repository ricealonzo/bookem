json.extract! location, :id, :name, :description, :address, :city, :state, :postal_code, :host_id, :created_at, :updated_at
json.url location_url(location, format: :json)
