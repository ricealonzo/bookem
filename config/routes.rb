Rails.application.routes.draw do
  devise_for :users

  resources :locations

  # Bookings are never deleted: they're confirmed, declined or cancelled so
  # both the guest and the host keep a record.
  resources :bookings, except: :destroy do
    member do
      patch :confirm
      patch :decline
      patch :cancel
    end
  end

  root to: "locations#index"
end
