# Lesson 1: Services and resources

**Branch:** `services-and-resources`
**Why it matters:** Before this change, Bookem could only rent out one space at a time. A barbershop with three barbers, or a studio with two rooms, couldn't use it. Now one codebase can serve almost any appointment business, which is what lets you sell it to more than one kind of customer.

## The idea in one picture

```
Location (Riverside Barbershop)
 ├── Resources  ← who or what gets booked        Marcus · Dee · Tony
 ├── Services   ← what the guest is buying       Haircut 30 min $30 · Fade + beard 1 hr $45
 ├── OpeningHours                                Tue–Sat 9 AM–6 PM
 └── Bookings   ← each one has ONE resource, and maybe a service
```

Two new words:

- **Resource**: the thing with a calendar. A room, a chair, a barber. Two bookings can happen at the same time as long as they're on different resources.
- **Service**: what the guest buys. It has a **length** and a **price**. The length decides how long the booking is, so the guest picks a start time, not an end time.

This is the same model Square Appointments, Calendly and Acuity use under the hood. Knowing it is a good interview talking point.

## What changed, file by file

### 1. The migration: `db/migrate/20261108120000_create_resources_and_services.rb`

It creates two tables and adds columns to `bookings` and `locations`. The interesting part is the **backfill**: live data already exists, so the migration has to bring old rows along.

```ruby
execute <<~SQL
  INSERT INTO resources (location_id, name, active, position, created_at, updated_at)
  SELECT id, 'Main space', TRUE, 0, NOW(), NOW() FROM locations
SQL
```

That one statement gives every existing location a resource called "Main space". The next statement points every old booking at its location's new resource. Old locations keep working exactly as before.

**Why SQL instead of `Location.find_each { ... }`?** Migrations live forever, but models change. If a migration uses the `Location` model and someone later adds a validation to it, the old migration can break. Plain SQL doesn't depend on today's model code.

**Why `price_cents` as an integer?** Money stored as a decimal or float can pick up rounding errors (0.1 + 0.2 = 0.30000000000000004). Whole cents never do. `app/models/concerns/money_field.rb` converts between "35.50" in a form and `3550` in the database.

**Why save the price on the booking?** If the barber raises the fade price next month, last month's bookings should still show what the customer agreed to pay. This is called a **snapshot**.

### 2. CI rehearses the migration: `.github/workflows/ci.yml`

The `migrations` job builds the database as it was months ago, inserts an old location and old bookings, then runs every new migration. `script/check_booking_migration.rb` checks that the old booking ended up on a "Main space" resource. Production data is the one thing you can't undo, so it's tested like code.

### 3. Picking a resource: `app/models/booking.rb`

Three `before_validation` callbacks run in order every time a booking is saved:

```ruby
before_validation :apply_service_length   # 1. service sets the end time
before_validation :assign_resource        # 2. pick the first free resource
before_validation :set_price, if: :new_record?  # 3. snapshot the price
```

The order matters. You can't find a free resource until you know the end time, and you can't price the booking until you know its length.

`assign_resource` only runs when the guest didn't choose:

```ruby
candidates = location.active_resources
self.resource = candidates.detect { |candidate| free_on?(candidate) } || candidates.first
```

If nobody's free, it still assigns the first one, so the overlap validation fails with a clear message ("Every barber is booked at that time").

**Security point:** the server sets `ended_at` from the service. A guest could edit the hidden form field to book a 4-hour slot for the price of a 30-minute cut, and the server ignores it. Never trust a value the browser sends when the server can work it out itself. The spec `"sets the booking's length from the service, ignoring the end time sent"` proves it.

### 4. No double-booking, per resource

The overlap check used to ask "is anything else booked at this location?" Now it asks "is anything else booked on this resource?":

```ruby
Booking.active.where(resource_id: resource.id).where.not(id: id).overlapping(started_at, ended_at)
```

The controller still wraps the save in `location.with_lock { ... }`. That's a database row lock: if two guests submit at the same moment, the second one waits until the first has finished saving, then runs its own check. Without it, both could pass the check before either saved.

### 5. The calendar: `Location#schedule_for`

A slot is **open** while at least one resource is free in it:

```ruby
pool = resource ? [ resource.id ] : active_resources.map(&:id)
free = pool.size - taken.map(&:resource_id).uniq.size
```

Pass `resource:` and you get one barber's own calendar. That's what the "Barber: Any available / Marcus / Dee" dropdown on the location page uses.

### 6. The host's setup page

- Routes are **nested**: `/locations/7/services` and `/locations/7/resources/3`. The URL itself says which location you're working on.
- `ServicesController` and `ResourcesController` always look records up through the location: `@location.services.find(id)`. A host can't edit another location's service by changing the id in the URL, because it isn't in `@location.services`.
- `LocationSetupPolicy` (Pundit) says only the location's host can do anything here. `ServicePolicy` and `ResourcePolicy` inherit from it, so the rule lives in one place.
- Things with bookings are **retired** (`active: false`), not deleted, so old bookings still say "with Marcus". This is a **soft delete**.

### 7. The browser side: `app/javascript/controllers/booking_picker_controller.js`

This is a Stimulus controller. When there's a service dropdown, clicking a slot means "start here". The controller reads how many slots the service needs from a `data-slots` attribute and checks they're all open:

```js
const to = index + length - 1
if (this.allOpen(day, index, to)) this.select(day, index, to)
```

The resource dropdown is a small GET form aimed at the `bookings_calendar` Turbo Frame. Changing it reloads only the calendar, not the whole page.

## Try it yourself

```bash
git checkout services-and-resources
bin/rails db:migrate
bin/rails sample_data      # wipes data, then adds a barbershop with 3 barbers and services
bin/dev
```

1. Log in as `guest1@example.com` (password `password`) and open **Riverside Barbershop**.
2. Pick "Fade and beard trim", then a start time. Two 30-minute slots get selected.
3. Switch the Barber dropdown to "Dee" and watch the calendar change.
4. Log in as the barbershop's host and open **Services and barbers** to add a service.

Run the tests for this lesson:

```bash
bundle exec rspec spec/models/services_and_resources_spec.rb spec/requests/services_spec.rb
```

## Check your understanding

1. Why does `assign_resource` have to run after `apply_service_length`?
2. A host deletes the barber "Tony", who has bookings next week. What happens, and why is that better than deleting the row?
3. Why is the overlap check still wrapped in `location.with_lock` even though it's now per resource?
4. Where would you add a "buffer" of 15 minutes between bookings for cleanup? (Hint: look at `overlapping`.)

## How to talk about it in an interview

> "I generalized a single-space booking app into a multi-resource scheduler. I added resources and services, wrote a migration that backfilled live data in SQL, and rehearsed it in CI against an old copy of the schema. Overlap checks run per resource under a row lock, and the server works out the booking's length and price from the service, so a guest can't change them in the browser."
