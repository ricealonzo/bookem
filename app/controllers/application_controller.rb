class ApplicationController < ActionController::Base
  include Pundit::Authorization

  before_action :configure_permitted_parameters, if: :devise_controller?

  rescue_from Pundit::NotAuthorizedError, with: :not_authorized

  protected

  def configure_permitted_parameters
    extra_keys = [:first_name, :last_name, :organization, :phone_number, :website]
    devise_parameter_sanitizer.permit(:sign_up, keys: extra_keys)
    devise_parameter_sanitizer.permit(:account_update, keys: extra_keys)
  end

  private

  def not_authorized
    respond_to do |format|
      format.html { redirect_back_or_to root_path, alert: "You're not allowed to do that." }
      format.json { head :forbidden }
    end
  end
end
