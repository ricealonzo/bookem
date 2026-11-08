module ApplicationHelper
  # 3500 => "$35", 3550 => "$35.50", 0 => "Free"
  def money_label(cents)
    cents = cents.to_i
    return "Free" if cents.zero?

    dollars = cents / 100.0
    (cents % 100).zero? ? "$#{number_with_delimiter(cents / 100)}" : number_to_currency(dollars)
  end

  # 45 => "45 min", 60 => "1 hr", 90 => "1 hr 30 min", 120 => "2 hrs"
  def duration_label(minutes)
    minutes = minutes.to_i
    hours, mins = minutes.divmod(60)
    parts = []
    parts << (hours == 1 ? "1 hr" : "#{hours} hrs") if hours.positive?
    parts << "#{mins} min" if mins.positive? || parts.empty?
    parts.join(" ")
  end
end
