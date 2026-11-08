# The Account tab in the apps (and /account on the web): everything that
# lives in the web header, as a list. Signed-out visitors see log in and
# sign up.
class AccountsController < ApplicationController
  # GET /account
  def show
    @locations = current_user ? current_user.locations.order(:created_at).to_a : []
  end
end
