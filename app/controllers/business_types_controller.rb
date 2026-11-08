# Sales pages for business owners: /for lists every kind of business, and
# /for/barbershop explains what Bookem does for a barbershop.
class BusinessTypesController < ApplicationController
  # GET /for
  def index
    @business_types = BusinessType.all
  end

  # GET /for/barbershop
  def show
    @business_type = BusinessType.find(params[:key])
    return render(file: Rails.public_path.join("404.html"), status: :not_found, layout: false) unless @business_type

    @example = Location.includes(:services).where(business_type: @business_type.key).order(:created_at).first
  end
end
