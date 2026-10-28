module LocationsHelper
  def slot_length_label(minutes)
    case minutes
    when 30 then "30 minutes"
    when 60 then "1 hour"
    when 90 then "1.5 hours"
    when 480 then "8 hours"
    else "#{minutes / 60} hours"
    end
  end

  def slot_length_options
    Location::SLOT_LENGTHS.map { |minutes| [ slot_length_label(minutes), minutes ] }
  end

  # "9 AM" / "5:30 PM" / "Midnight" for a minute-of-day.
  def minute_label(minute)
    return "midnight" if minute >= 1440 || minute.zero?

    hour = minute / 60
    min = minute % 60
    suffix = hour < 12 ? "AM" : "PM"
    hour12 = hour % 12
    hour12 = 12 if hour12.zero?
    min.zero? ? "#{hour12} #{suffix}" : format("%d:%02d %s", hour12, min, suffix)
  end

  def hours_label(hours)
    "#{minute_label(hours.opens_at_minute)} to #{minute_label(hours.closes_at_minute)}"
  end

  # The week's hours with days that share the same hours grouped:
  # [["Monday to Friday", "9 AM to 5 PM"], ["Saturday", "10 AM to 2 PM"], ["Sunday", "Closed"]]
  def weekly_hours_summary(location)
    order = [ 1, 2, 3, 4, 5, 6, 0 ]
    by_day = order.map do |weekday|
      hours = location.hours_for(Date.current.beginning_of_week(:sunday) + weekday)
      [ weekday, hours ? hours_label(hours) : "Closed" ]
    end

    groups = by_day.slice_when { |a, b| a[1] != b[1] }.to_a
    groups.map do |group|
      first = Date::DAYNAMES[group.first[0]]
      last = Date::DAYNAMES[group.last[0]]
      days = group.size == 1 ? first : (group.size == 2 ? "#{first} and #{last}" : "#{first} to #{last}")
      [ days, group.first[1] ]
    end
  end
end
