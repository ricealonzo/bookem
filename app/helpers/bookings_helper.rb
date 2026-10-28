module BookingsHelper
  # "10 AM" or "10:30 AM"
  def short_time(time)
    time.strftime(time.min.zero? ? "%-l %p" : "%-l:%M %p")
  end

  # How a booking reads inside one calendar day.
  def booking_time_label(booking, day)
    starts_today = booking.started_at.to_date == day
    ends_today = booking.ended_at.to_date == day

    if starts_today && ends_today
      "#{short_time(booking.started_at)}–#{short_time(booking.ended_at)}"
    elsif starts_today
      "From #{short_time(booking.started_at)}"
    elsif ends_today
      "Until #{short_time(booking.ended_at)}"
    else
      "All day"
    end
  end

  # "Tue, Nov 3, 10 AM–12 PM", or a range across days.
  def booking_range_label(booking)
    starts = booking.started_at
    ends = booking.ended_at
    day = ->(time) { time.strftime("%a, %b %-d") }

    if starts.to_date == ends.to_date
      "#{day.call(starts)}, #{short_time(starts)}–#{short_time(ends)}"
    else
      "#{day.call(starts)}, #{short_time(starts)} to #{day.call(ends)}, #{short_time(ends)}"
    end
  end

  # The bookings that actually take up time on this day (a booking that ends
  # exactly at midnight doesn't count for the next day).
  def bookings_on(day, bookings)
    bookings.reject { |booking| booking.ended_at == day.beginning_of_day }
  end

  # The month the calendar is showing, from simple_calendar's start_date param.
  def calendar_month_start(start_date_param)
    Date.parse(start_date_param.to_s).beginning_of_month
  rescue Date::Error
    Date.current.beginning_of_month
  end

  def bookings_in_month(bookings, month_start)
    month_end = month_start.end_of_month.end_of_day
    bookings
      .select { |booking| booking.started_at <= month_end && booking.ended_at > month_start.beginning_of_day }
      .sort_by(&:started_at)
  end
end
