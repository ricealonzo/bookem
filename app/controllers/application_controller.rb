class ApplicationController < ActionController::Base
  include Pundit::Authorization

  before_action :configure_permitted_parameters, if: :devise_controller?

  rescue_from Pundit::NotAuthorizedError, with: :not_authorized

  helper_method :native_app?

  protected

  def configure_permitted_parameters
    extra_keys = [:first_name, :last_name, :organization, :phone_number, :website]
    devise_parameter_sanitizer.permit(:sign_up, keys: extra_keys)
    devise_parameter_sanitizer.permit(:account_update, keys: extra_keys)
  end

  private

  # True inside the Bookem iOS and Android apps. Hotwire Native adds
  # "Hotwire Native iOS;" or "Hotwire Native Android;" to the user agent,
  # and the apps add "Bookem iOS;" / "Bookem Android;" in front of it.
  def native_app?
    request.user_agent.to_s.match?(/Hotwire Native|Turbo Native/)
  end

  def not_authorized
    respond_to do |format|
      format.html { redirect_back_or_to root_path, alert: "You're not allowed to do that." }
      format.json { head :forbidden }
    end
  end
end
