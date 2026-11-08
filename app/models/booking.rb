# == Schema Information
#
# Table name: bookings
#
#  id          :bigint           not null, primary key
#  deposit_cents :integer        default(0), not null
#  ended_at    :datetime
#  payment_expires_at :datetime
#  payment_status :string        default("not_required"), not null
#  price_cents :integer          default(0), not null
#  started_at  :datetime
#  status      :string           default("pending"), not null
#  stripe_checkout_session_id :string
#  stripe_payment_intent_id :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  guest_id    :integer
#  location_id :integer
#  resource_id :bigint
#  service_id  :bigint
#
# Indexes
#
#  index_bookings_on_guest_id                  (guest_id)
#  index_bookings_on_location_id_and_started_at  (location_id,started_at)
#  index_bookings_on_resource_id_and_started_at  (resource_id,started_at)
#  index_bookings_on_service_id                (service_id)
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

  # The deposit, when the location asks for one:
  #   not_required → no deposit
  #   awaiting     → the guest is paying; the time is held until payment_expires_at
  #   paid → refunded, or expired (the hold ran out before payment)
  enum :payment_status, {
    not_required: "not_required",
    awaiting: "awaiting",
    paid: "paid",
    refunded: "refunded",
    expired: "expired"
  }, prefix: :deposit, default: :not_required, validate: true

  # Bookings that hold their time slot.
  ACTIVE_STATUSES = %w[pending confirmed].freeze

  belongs_to :guest, class_name: "User", foreign_key: "guest_id", counter_cache: true
  belongs_to :location, class_name: "Location", foreign_key: "location_id"
  # Who or what is booked (a room, a chair, a barber). Picked automatically
  # when the guest doesn't choose.
  belongs_to :resource
  # What the guest is buying, when the location offers services.
  belongs_to :service, optional: true
  has_one :host, through: :location, source: :host

  # A service decides the booking's length; then the first free resource is
  # picked and the price is worked out.
  before_validation :apply_service_length
  before_validation :assign_resource
  before_validation :set_price, if: :new_record?
  before_validation :set_deposit, if: :new_record?

  validates :started_at, presence: true
  validates :ended_at, presence: true
  validate :ends_after_start
  validate :not_too_long
  validate :starts_in_future, if: :times_changed?
  validate :within_opening_hours, if: :times_changed?
  validate :guest_is_not_host
  validate :resource_belongs_to_location, if: -> { new_record? || resource_id_changed? }
  validate :service_belongs_to_location, if: -> { new_record? || service_id_changed? }
  validate :service_chosen, if: :new_record?
  validate :no_overlap, if: :active?

  # Pending and confirmed bookings hold their time, except a deposit hold
  # that ran out before the guest paid.
  scope :active, lambda {
    where(status: ACTIVE_STATUSES)
      .where("bookings.payment_status <> 'awaiting' OR bookings.payment_expires_at > ?", Time.current)
  }
  scope :upcoming, -> { where(ended_at: Time.current..) }
  scope :chronological, -> { order(:started_at) }
  scope :overlapping, ->(starts, ends) { where("bookings.started_at < ? AND bookings.ended_at > ?", ends, starts) }

  def active?
    ACTIVE_STATUSES.include?(status) && !payment_lapsed?
  end

  # The guest didn't pay the deposit in time, so the time is free again.
  def payment_lapsed?
    deposit_awaiting? && (payment_expires_at.nil? || payment_expires_at <= Time.current)
  end

  def upcoming?
    started_at.present? && started_at > Time.current
  end

  def cancellable?
    active? && upcoming?
  end

  # Hosts only see a request once any deposit is paid.
  def respondable?
    pending? && upcoming? && !deposit_awaiting?
  end

  # "$20.00", or nil when there's no deposit.
  def deposit_label
    return nil unless deposit_cents.to_i.positive?

    format("$%.2f", deposit_cents / 100.0)
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

  # "$35.00", or nil when the booking is free.
  def price_label
    return nil unless price_cents.to_i.positive?

    format("$%.2f", price_cents / 100.0)
  end

  private

  def apply_service_length
    return if service.blank? || started_at.blank?
    return unless new_record? || service_id_changed? || started_at_changed?

    self.ended_at = started_at + service.duration_minutes.minutes
  end

  # With no resource chosen, use the first one that's free for the whole time.
  def assign_resource
    return if resource.present? || location.blank?

    candidates = location.active_resources
    @resource_picked_for_guest = true
    self.resource = candidates.detect { |candidate| free_on?(candidate) } || candidates.first
  end

  def set_price
    return if location.blank?

    self.price_cents =
      if service.present?
        service.price_cents
      elsif started_at.present? && ended_at.present? && ended_at > started_at
        slots = ((ended_at - started_at) / 60.0 / location.slot_minutes).ceil
        slots * location.slot_price_cents
      else
        0
      end
  end

  def set_deposit
    self.deposit_cents = Deposits.amount_for(self)
    if deposit_cents.positive?
      self.payment_status = :awaiting
      self.payment_expires_at = Time.current + Deposits::HOLD
    else
      self.payment_status = :not_required
    end
  end

  def free_on?(candidate)
    return true if started_at.blank? || ended_at.blank?

    !Booking.active.where(resource_id: candidate.id).where.not(id: id).overlapping(started_at, ended_at).exists?
  end

  def resource_belongs_to_location
    return if resource.blank? || location.blank?

    if resource.location_id != location.id
      errors.add(:resource, "isn't part of this location")
    elsif !resource.active?
      errors.add(:resource, "isn't taking bookings anymore")
    end
  end

  def service_belongs_to_location
    return if service.blank? || location.blank?

    if service.location_id != location.id
      errors.add(:service, "isn't offered at this location")
    elsif !service.active?
      errors.add(:service, "isn't offered anymore")
    end
  end

  def service_chosen
    return if location.blank? || service.present?

    errors.add(:base, "Choose a service to book") if location.uses_services?
  end

  def times_changed?
    new_record? || started_at_changed? || ended_at_changed?
  end

  # The host's hours and slot length decide which times can be booked.
  def within_opening_hours
    return if started_at.blank? || ended_at.blank? || location.blank? || ended_at <= started_at

    problem = location.booking_hours_problem(started_at, ended_at)
    errors.add(:base, "This time #{problem}") if problem&.start_with?("must")
    errors.add(:base, problem) if problem && !problem.start_with?("must")
  end

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

  # Each resource can only be in one booking at a time.
  def no_overlap
    return if started_at.blank? || ended_at.blank? || resource.blank?

    clash = Booking.active
      .where(resource_id: resource.id)
      .where.not(id: id)
      .overlapping(started_at, ended_at)
      .exists?
    return unless clash

    errors.add(:base, overlap_message)
  end

  def overlap_message
    if location.blank? || location.active_resources.size <= 1
      "That time overlaps another booking for this location"
    elsif @resource_picked_for_guest
      "Every #{location.resource_label.downcase} is booked at that time"
    else
      "#{resource.name} is already booked at that time"
    end
  end
end
