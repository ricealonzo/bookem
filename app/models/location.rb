# == Schema Information
#
# Table name: locations
#
#  id          :bigint           not null, primary key
#  address     :string
#  city        :string
#  description :string
#  image       :string
#  name        :string
#  postal_code :string
#  slot_minutes :integer         default(60), not null
#  state       :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  host_id     :integer
#
class Location < ApplicationRecord
  # Slot lengths a host can choose, in minutes.
  SLOT_LENGTHS = [ 30, 60, 90, 120, 180, 240, 480 ].freeze

  # Hours a new location starts with: Monday to Friday, 9 AM to 5 PM.
  DEFAULT_HOURS = (1..5).map { |weekday| { weekday: weekday, opens_at_minute: 540, closes_at_minute: 1020 } }.freeze

  # One time slot on one day, and what's happening in it.
  Slot = Struct.new(:starts_at, :ends_at, :state, :booking, keyword_init: true) do
    def open? = state == :open
  end

  validates :name, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 2000 }
  validates :address, presence: true
  validates :city, presence: true
  validates :state, presence: true
  validates :postal_code, presence: true
  validates :slot_minutes, inclusion: { in: SLOT_LENGTHS, message: "isn't one of the offered lengths" }
  validate :open_at_least_one_day

  belongs_to :host, class_name: "User", foreign_key: "host_id", counter_cache: true

  has_many :bookings, class_name: "Booking", foreign_key: "location_id", dependent: :destroy
  has_many :opening_hours, -> { order(:weekday) }, dependent: :destroy, autosave: true, inverse_of: :location

  mount_uploader :image, ImageUploader

  before_validation :apply_default_hours, on: :create

  def full_address
    [ address, city, state, postal_code ].compact_blank.join(", ")
  end

  def hosted_by?(user)
    user.present? && host_id == user.id
  end

  # Opening hours that will still exist after saving.
  def current_opening_hours
    opening_hours.reject(&:marked_for_destruction?).sort_by(&:weekday)
  end

  def hours_for(date)
    current_opening_hours.detect { |hours| hours.weekday == date.wday }
  end

  # Sets the weekly hours from the location form:
  #   { "1" => { "open" => "1", "opens_at" => "09:00", "closes_at" => "17:00" }, ... }
  # Days not marked open are closed.
  def weekly_hours=(days)
    @weekly_hours_given = true
    days = days.to_h.stringify_keys
    (0..6).each do |weekday|
      day = (days[weekday.to_s] || {}).to_h.stringify_keys
      existing = opening_hours.detect { |hours| hours.weekday == weekday }

      if ActiveModel::Type::Boolean.new.cast(day["open"])
        hours = existing || opening_hours.build(weekday: weekday)
        hours.opens_at_text = day["opens_at"]
        hours.closes_at_text = day["closes_at"]
      elsif existing
        existing.mark_for_destruction
      end
    end
  end

  # The wall-clock time on a date, in the app's time zone (handles DST).
  def time_on(date, minute)
    day = date.in_time_zone.beginning_of_day
    return day.next_day if minute >= 1440

    day.change(hour: minute / 60, min: minute % 60)
  end

  # The slots a guest could book on a date, earliest first.
  def slots_for(date)
    hours = hours_for(date)
    return [] unless hours

    minutes = (hours.opens_at_minute..(hours.closes_at_minute - slot_minutes)).step(slot_minutes)
    minutes.map do |minute|
      Slot.new(starts_at: time_on(date, minute), ends_at: time_on(date, minute + slot_minutes))
    end
  end

  # Each slot on a date with its state: :past, :booked, :requested or :open.
  # Pass the location's active bookings to avoid a query per day.
  def schedule_for(date, active_bookings = bookings.active.to_a, now: Time.current)
    slots_for(date).each do |slot|
      booking = active_bookings.detect { |b| b.started_at < slot.ends_at && b.ended_at > slot.starts_at }
      slot.booking = booking
      slot.state =
        if slot.starts_at <= now then :past
        elsif booking&.confirmed? then :booked
        elsif booking then :requested
        else :open
        end
    end
  end

  # Whether a time range fits inside one day's hours and lines up with slots.
  def bookable_range?(starts_at, ends_at)
    booking_hours_problem(starts_at, ends_at).nil?
  end

  # Why a time range can't be booked here, or nil if it can.
  def booking_hours_problem(starts_at, ends_at)
    date = starts_at.in_time_zone.to_date
    hours = hours_for(date)
    return "#{name} isn't open on #{date.strftime('%A')}s" unless hours

    opens = time_on(date, hours.opens_at_minute)
    closes = time_on(date, hours.closes_at_minute)
    return "must be within opening hours (#{opens.strftime('%-l:%M %p')} to #{closes.strftime('%-l:%M %p')})" if starts_at < opens || ends_at > closes

    from_open = ((starts_at - opens) / 60).round
    length = ((ends_at - starts_at) / 60).round
    unless (from_open % slot_minutes).zero? && (length % slot_minutes).zero?
      return "must start and end on the #{slot_minutes}-minute slots"
    end

    nil
  end

  private

  def apply_default_hours
    return if @weekly_hours_given || opening_hours.any?

    DEFAULT_HOURS.each { |attrs| opening_hours.build(attrs) }
  end

  def open_at_least_one_day
    errors.add(:base, "Choose at least one day when guests can book") if current_opening_hours.empty?
  end
end
