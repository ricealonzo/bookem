Rails.application.routes.draw do
  devise_for :users

  resources :locations do
    # The host's setup: services guests can book, and the rooms, chairs or
    # people that get booked.
    resources :services, only: %i[ index create update destroy ]
    resources :resources, only: %i[ create update destroy ]
  end

  # Bookings are never deleted: they're confirmed, declined or cancelled so
  # both the guest and the host keep a record.
  resources :bookings, only: %i[ index show new create ] do
    member do
      patch :confirm
      patch :decline
      patch :cancel
      post :pay
    end
  end

  # Hosts connect a Stripe account so deposits are paid out to them.
  resource :payouts, only: :show do
    post :connect
    get :done
    get :refresh
  end

  # Stripe tells Bookem when a deposit is paid or a payment page expires.
  post "stripe/webhook", to: "stripe_webhooks#create", as: :stripe_webhook

  root to: "locations#index"
end
