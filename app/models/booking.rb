# == Schema Information
#
# Table name: bookings
#
#  id          :bigint           not null, primary key
#  ended_at    :datetime
#  started_at  :datetime
#  status      :string           default("pending"), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  guest_id    :integer
#  location_id :integer
#
# Indexes
#
#  index_bookings_on_guest_id                  (guest_id)
#  index_bookings_on_location_id_and_started_at  (location_id,started_at)
#
class Booking < ApplicationRecord
  MAX_LENGTH = 30.days

  class InvalidTransition < StandardError; end

  # A guest requests a booking (pending); the host confirms or declines it.
  # Either side can cancel a pending or confirmed booking before it starts.
  enum :status, {
    pending: "pending",
    confirmed: "confirmed",
    declined: "declined",
    cancelled: "cancelled"
  }, default: :pending, validate: true

  # Bookings that hold their time slot.
  ACTIVE_STATUSES = %w[pending confirmed].freeze

  belongs_to :guest, class_name: "User", foreign_key: "guest_id", counter_cache: true
  belongs_to :location, class_name: "Location", foreign_key: "location_id"
  has_one :host, through: :location, source: :host

  validates :started_at, presence: true
  validates :ended_at, presence: true
  validate :ends_after_start
  validate :not_too_long
  validate :starts_in_future, if: -> { started_at_changed? || ended_at_changed? }
  validate :guest_is_not_host
  validate :no_overlap, if: :active?

  scope :active, -> { where(status: ACTIVE_STATUSES) }
  scope :upcoming, -> { where(ended_at: Time.current..) }
  scope :chronological, -> { order(:started_at) }
  scope :overlapping, ->(starts, ends) { where("bookings.started_at < ? AND bookings.ended_at > ?", ends, starts) }

  def active?
    ACTIVE_STATUSES.include?(status)
  end

  def upcoming?
    started_at.present? && started_at > Time.current
  end

  def cancellable?
    active? && upcoming?
  end

  def editable?
    pending? && upcoming?
  end

  def respondable?
    pending? && upcoming?
  end

  def confirm!
    raise InvalidTransition, "This booking can't be changed anymore" unless respondable?

    update!(status: :confirmed)
  end

  def decline!
    raise InvalidTransition, "This booking can't be changed anymore" unless respondable?

    update!(status: :declined)
  end

  def cancel!
    raise InvalidTransition, "This booking can't be cancelled" unless cancellable?

    update!(status: :cancelled)
  end

  private

  def ends_after_start
    return if started_at.blank? || ended_at.blank?

    errors.add(:ended_at, "must be after the start time") if ended_at <= started_at
  end

  def not_too_long
    return if started_at.blank? || ended_at.blank?

    errors.add(:ended_at, "can't be more than 30 days after the start time") if ended_at - started_at > MAX_LENGTH
  end

  def starts_in_future
    return if started_at.blank?

    errors.add(:started_at, "must be in the future") if started_at <= Time.current
  end

  def guest_is_not_host
    return if location.blank? || guest_id.blank?

    errors.add(:base, "You can't book your own location") if location.host_id == guest_id
  end

  def no_overlap
    return if started_at.blank? || ended_at.blank? || location_id.blank?

    clash = Booking.active
      .where(location_id: location_id)
      .where.not(id: id)
      .overlapping(started_at, ended_at)
      .exists?

    errors.add(:base, "That time overlaps another booking for this location") if clash
  end
end
