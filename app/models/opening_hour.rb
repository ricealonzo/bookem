# == Schema Information
#
# Table name: opening_hours
#
#  id               :bigint           not null, primary key
#  closes_at_minute :integer          not null
#  opens_at_minute  :integer          not null
#  weekday          :integer          not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  location_id      :bigint           not null
#
# When a location takes bookings on one day of the week. Times are stored as
# minutes after midnight; a closing time of 1440 means midnight.
class OpeningHour < ApplicationRecord
  belongs_to :location, inverse_of: :opening_hours

  validates :weekday, inclusion: { in: 0..6 }, uniqueness: { scope: :location_id }
  validates :opens_at_minute, numericality: { only_integer: true, in: 0..1439 }
  validates :closes_at_minute, numericality: { only_integer: true, in: 1..1440 }
  validate :closes_after_opening
  validate :fits_a_slot

  def day_name
    Date::DAYNAMES[weekday]
  end

  # "09:00", for time inputs. Midnight closing shows as "00:00".
  def opens_at_text = self.class.minute_to_text(opens_at_minute)
  def closes_at_text = self.class.minute_to_text(closes_at_minute)

  def opens_at_text=(text)
    self.opens_at_minute = self.class.text_to_minute(text)
  end

  # "00:00" as a closing time means midnight at the end of the day.
  def closes_at_text=(text)
    minute = self.class.text_to_minute(text)
    self.closes_at_minute = minute&.zero? ? 1440 : minute
  end

  def self.minute_to_text(minute)
    return "" if minute.nil?

    format("%02d:%02d", (minute / 60) % 24, minute % 60)
  end

  def self.text_to_minute(text)
    match = text.to_s.match(/\A(\d{1,2}):(\d{2})/)
    return nil unless match

    match[1].to_i * 60 + match[2].to_i
  end

  private

  def closes_after_opening
    return if opens_at_minute.blank? || closes_at_minute.blank?

    errors.add(:base, "#{day_name}: closing time must be after opening time") if closes_at_minute <= opens_at_minute
  end

  def fits_a_slot
    return if opens_at_minute.blank? || closes_at_minute.blank? || location.blank?
    return if closes_at_minute <= opens_at_minute

    if closes_at_minute - opens_at_minute < location.slot_minutes.to_i
      errors.add(:base, "#{day_name}: open hours are shorter than one slot")
    end
  end
end
