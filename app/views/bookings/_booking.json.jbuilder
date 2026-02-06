json.extract! booking, :id, :started_at, :ended_at, :guest_id, :location_id, :created_at, :updated_at
json.url booking_url(booking, format: :json)
