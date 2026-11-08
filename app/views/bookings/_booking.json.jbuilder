json.extract! booking, :id, :status, :started_at, :ended_at, :guest_id, :location_id, :resource_id, :service_id, :price_cents, :created_at, :updated_at
json.url booking_url(booking, format: :json)
