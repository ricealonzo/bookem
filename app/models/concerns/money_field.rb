# Prices are stored as whole cents (an integer) so there's never a rounding
# error, and shown as dollars in forms.
#
#   money_field :price      # adds #price_dollars and #price_dollars= for price_cents
module MoneyField
  extend ActiveSupport::Concern

  class_methods do
    def money_field(name)
      cents = :"#{name}_cents"

      define_method(:"#{name}_dollars") do
        value = self[cents].to_i
        format("%.2f", value / 100.0)
      end

      define_method(:"#{name}_dollars=") do |text|
        self[cents] = MoneyField.to_cents(text)
      end
    end
  end

  # "35", "$35.50", "1,200" => cents. Blank or unreadable => 0.
  def self.to_cents(text)
    cleaned = text.to_s.gsub(/[$,\s]/, "")
    return 0 if cleaned.blank?
    return 0 unless cleaned.match?(/\A\d+(\.\d{1,2})?\z/)

    (BigDecimal(cleaned) * 100).to_i
  end
end
