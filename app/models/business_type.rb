# The kinds of business Bookem is set up for. Each one is a preset: what
# its resources are called, a typical slot length, hours, starter services,
# and the words for its landing page at /for/<key>.
#
# One engine, many niches: adding a business type is adding an entry here.
# Starter services and hours are only a starting point; hosts change them.
class BusinessType
  Preset = Struct.new(
    :key, :name, :plural, :resource_label, :resources, :slot_minutes, :slot_price_cents,
    :deposit_percent, :hours, :services, :headline, :pain, :perks,
    keyword_init: true
  )

  WEEKDAYS = 1..5
  TUE_TO_SAT = 2..6
  EVERY_DAY = 0..6

  PRESETS = [
    Preset.new(
      key: "recording_studio", name: "Recording studio", plural: "recording studios",
      resource_label: "Room", resources: [ "Studio A" ], slot_minutes: 60, slot_price_cents: 0,
      deposit_percent: 50, hours: { days: EVERY_DAY, opens: "12:00", closes: "00:00" },
      services: [
        { name: "Studio time with engineer", duration_minutes: 120, price_cents: 10_000 },
        { name: "Studio time, self-engineered", duration_minutes: 120, price_cents: 6_000 },
        { name: "Mix and master", duration_minutes: 180, price_cents: 15_000 }
      ],
      headline: "Stop booking sessions in your DMs.",
      pain: "Artists ask for time in your DMs, you trade messages to find a slot, and half of them don't show.",
      perks: [
        "Artists see open hours and book their own session.",
        "A deposit up front, so a no-show doesn't cost you the night.",
        "Separate calendars for each room or engineer."
      ]
    ),
    Preset.new(
      key: "barbershop", name: "Barbershop", plural: "barbershops",
      resource_label: "Barber", resources: [ "Chair 1" ], slot_minutes: 30, slot_price_cents: 0,
      deposit_percent: 25, hours: { days: TUE_TO_SAT, opens: "09:00", closes: "19:00" },
      services: [
        { name: "Haircut", duration_minutes: 30, price_cents: 3_000 },
        { name: "Haircut and beard", duration_minutes: 60, price_cents: 4_500 },
        { name: "Kids cut", duration_minutes: 30, price_cents: 2_000 }
      ],
      headline: "A full chair, every day.",
      pain: "Walk-ins are unpredictable, texts pile up, and no-shows leave gaps you can't fill.",
      perks: [
        "Clients pick their barber and service, and book a time themselves.",
        "Each barber has their own calendar.",
        "A small deposit makes no-shows rare."
      ]
    ),
    Preset.new(
      key: "salon", name: "Hair salon", plural: "hair salons",
      resource_label: "Stylist", resources: [ "Stylist 1" ], slot_minutes: 60, slot_price_cents: 0,
      deposit_percent: 25, hours: { days: TUE_TO_SAT, opens: "10:00", closes: "19:00" },
      services: [
        { name: "Silk press", duration_minutes: 120, price_cents: 8_500 },
        { name: "Braids", duration_minutes: 240, price_cents: 18_000 },
        { name: "Trim", duration_minutes: 60, price_cents: 3_500 }
      ],
      headline: "Long appointments, protected.",
      pain: "A four-hour appointment that doesn't show up is a whole afternoon gone.",
      perks: [
        "Services book the right amount of time automatically.",
        "Deposits on long services, refunded if you cancel.",
        "Clients choose their stylist."
      ]
    ),
    Preset.new(
      key: "tattoo_shop", name: "Tattoo shop", plural: "tattoo shops",
      resource_label: "Artist", resources: [ "Artist 1" ], slot_minutes: 60, slot_price_cents: 0,
      deposit_percent: 25, hours: { days: TUE_TO_SAT, opens: "12:00", closes: "20:00" },
      services: [
        { name: "Consultation", duration_minutes: 60, price_cents: 0 },
        { name: "Small piece", duration_minutes: 120, price_cents: 15_000 },
        { name: "Half-day session", duration_minutes: 240, price_cents: 40_000 }
      ],
      headline: "Deposits taken before the stencil comes out.",
      pain: "Chasing deposits over payment apps and keeping a paper calendar for every artist.",
      perks: [
        "Deposits collected when the client books.",
        "One calendar per artist.",
        "Free consultations alongside paid sessions."
      ]
    ),
    Preset.new(
      key: "photo_studio", name: "Photo or video studio", plural: "photo and video studios",
      resource_label: "Studio", resources: [ "Main studio" ], slot_minutes: 60, slot_price_cents: 7_500,
      deposit_percent: 50, hours: { days: EVERY_DAY, opens: "08:00", closes: "22:00" },
      services: [],
      headline: "Rent your studio by the hour.",
      pain: "Hourly rentals mean lots of short bookings, and every one is a back-and-forth.",
      perks: [
        "Creators book any run of open hours.",
        "Your hourly rate, priced automatically.",
        "Deposits so a cancelled shoot doesn't leave you empty."
      ]
    ),
    Preset.new(
      key: "rehearsal_space", name: "Rehearsal space", plural: "rehearsal spaces",
      resource_label: "Room", resources: [ "Room 1" ], slot_minutes: 60, slot_price_cents: 2_500,
      deposit_percent: 0, hours: { days: EVERY_DAY, opens: "10:00", closes: "00:00" },
      services: [],
      headline: "Every room booked, every night.",
      pain: "Bands book late at night, when you're not answering your phone.",
      perks: [
        "Bands book open rooms any time.",
        "Each room has its own calendar.",
        "Hourly pricing worked out for you."
      ]
    ),
    Preset.new(
      key: "event_space", name: "Event space", plural: "event spaces",
      resource_label: "Space", resources: [ "Main hall" ], slot_minutes: 240, slot_price_cents: 40_000,
      deposit_percent: 50, hours: { days: EVERY_DAY, opens: "08:00", closes: "00:00" },
      services: [],
      headline: "Book the hall without the phone tag.",
      pain: "Event inquiries take days of emails before anyone pays anything.",
      perks: [
        "Guests see open dates and request them directly.",
        "A deposit holds the date.",
        "You confirm every booking before it's final."
      ]
    )
  ].freeze

  OTHER = Preset.new(
    key: "other", name: "Something else", plural: "businesses", resource_label: "Room", resources: [],
    slot_minutes: 60, slot_price_cents: 0, deposit_percent: 0,
    hours: { days: WEEKDAYS, opens: "09:00", closes: "17:00" }, services: [], perks: []
  ).freeze

  KEYS = (PRESETS.map(&:key) + [ OTHER.key ]).freeze

  def self.all = PRESETS

  def self.find(key)
    PRESETS.detect { |preset| preset.key == key.to_s }
  end

  def self.fetch(key)
    find(key) || OTHER
  end

  # { "2" => { "open" => "1", "opens_at" => "09:00", "closes_at" => "19:00" }, ... }
  # in the shape the location form sends.
  def self.weekly_hours(preset)
    preset.hours[:days].to_a.to_h do |weekday|
      [ weekday.to_s, { "open" => "1", "opens_at" => preset.hours[:opens], "closes_at" => preset.hours[:closes] } ]
    end
  end
end
