# Lesson 3: One engine, many niches

**Branch:** `niche-presets` (built on top of `stripe-deposits`)
**Why it matters:** Lessons 1 and 2 made Bookem *able* to run a barbershop or a recording studio. This lesson makes it *easy to sell* to them. A barber who signs up sees "Barbers", 30-minute slots and a Haircut service on day one, not a blank form. And every kind of business gets its own sales page and a link to share.

## The four pieces

| Piece | Where | What it does |
| --- | --- | --- |
| Presets | `app/models/business_type.rb` | Hours, slot length, wording, starter services and sales copy for each kind of business |
| Setup flow | `LocationsController#new` / `#create` | "What kind of business is it?" first, then a pre-filled form |
| Booking links | `Location#slug`, route `/b/:slug` | `bookem.com/b/riverside-barbershop` for an Instagram bio |
| Landing pages | `BusinessTypesController`, `/for/:key` | One sales page per niche, to send to shop owners |

## What changed, file by file

### 1. Presets as plain Ruby: `app/models/business_type.rb`

`BusinessType` isn't a database table. It's a frozen list of `Struct`s:

```ruby
Preset.new(
  key: "barbershop", name: "Barbershop", plural: "barbershops",
  resource_label: "Barber", resources: [ "Chair 1" ], slot_minutes: 30,
  services: [ { name: "Haircut", duration_minutes: 30, price_cents: 3_000 }, ... ],
  headline: "A full chair, every day.", ...
)
```

**Why not a table?** The presets change when *you* change the product, not when a user clicks something. Keeping them in code means they're reviewed in pull requests, tested, and identical on every server. The location only stores the key (`business_type: "barbershop"`).

**Adding a niche is adding one entry.** Want "Nail salon" or "Car detailing"? Copy a preset, change the words and services, and `spec/models/business_type_spec.rb` automatically tests it: the spec loops over every preset and checks it builds a working location with bookable slots. If you give a 45-minute service to a location with 30-minute slots, that test fails before a customer ever sees it.

### 2. Filling in the form: `Location#apply_business_type`

`/locations/new?type=barbershop` calls `apply_business_type("barbershop")`, which sets the slot length, resource label, price, deposit and builds the opening hours. The form then renders with those values already in it. The host can still change anything before saving.

After saving, `add_starter_setup!` renames "Main space" to the preset's first resource ("Chair 1") and creates the starter services. It uses `services.create` (no `!`), so if the host picked a slot length that a starter service doesn't fit, that one service is skipped instead of crashing the signup.

### 3. Booking links (slugs)

A **slug** is the readable part of a URL. `Location#fill_in_slug` runs before validation:

```ruby
base = name.to_s.parameterize        # "Riverside Barbershop" => "riverside-barbershop"
while Location.where.not(id: id).exists?(slug: candidate)
  number += 1
  candidate = "#{base}-#{number}"    # "riverside-barbershop-2"
end
```

Three layers keep slugs unique, from friendliest to strictest:

1. The loop picks a free one automatically.
2. `validates :slug, uniqueness: true` gives a friendly error if a host types a taken one.
3. A **unique index** in the database is the final guard, in case two hosts save at the exact same moment (the race the validation can't see).

`RESERVED_SLUGS` stops anyone from claiming words like `admin` or `payouts`. The migration gave existing locations `name-id` slugs in SQL, and CI checks that `Old Studio` became `old-studio-1`.

The route `get "b/:slug", to: "locations#show"` reuses the existing page. `set_location` just looks up by slug instead of id when there's a slug.

### 4. The copy button: `clipboard_controller.js`

A tiny Stimulus controller. `navigator.clipboard.writeText` copies the link, and the button says "Copied" for two seconds. Some phone browsers block clipboard access, so the `catch` tells the user to press and hold instead. Always plan for the browser saying no.

### 5. Landing pages: `/for` and `/for/:key`

These are **sales pages**, written for the shop owner, not the customer: their problem (`pain`), what Bookem does about it (`perks`), the starter services, and what it costs. The "List your barbershop" button goes straight to the pre-filled form. When you DM a barber, send them `/for/barbershop`, not the home page.

An unknown key returns a real 404, so search engines don't index junk URLs.

## Try it yourself

```bash
git checkout niche-presets
bin/rails db:migrate
bin/dev
```

1. Visit `/for` and open a couple of landing pages.
2. Sign in, choose **List your space**, pick **Recording studio**, and notice the form is already filled in.
3. Save it and look at the services page: the starter services are there.
4. On the location page, copy your booking link and open it in a private window.

```bash
bundle exec rspec spec/models/business_type_spec.rb spec/requests/business_types_spec.rb
```

## Check your understanding

1. Why does the spec loop over `BusinessType.all` instead of testing one preset?
2. Validation already checks slug uniqueness. Why does the database also need a unique index?
3. Add a "Nail salon" preset. Which files do you need to touch? (Answer: just one, plus nothing for tests.)
4. Why is `services.create` used instead of `services.create!` in `add_starter_setup!`?

## How to talk about it in an interview

> "I made the booking engine configurable per industry with code-defined presets: each business type sets hours, slot length, terminology and starter services, and a spec iterates every preset to prove it produces a bookable location. I added human-readable booking URLs with collision handling, validation and a unique index, and per-industry landing pages that feed a pre-filled signup."
