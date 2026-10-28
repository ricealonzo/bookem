# Bookem

Bookem lets small businesses list a space (a studio, salon chair, event loft and so on) and lets customers request time there. Hosts confirm or decline each request, and both sides keep a record of every booking.

**Live site:** https://bookem-4pho.onrender.com

Built with Ruby 3.4 and Rails 8.1, PostgreSQL, Devise, Pundit, Stimulus and Cloudinary, and deployed on Render.

## Features

- **Browse locations** with photos, details and a map (Mapbox).
- **Host-set hours.** Each host chooses which days the location is open, the opening and closing times, and a slot length (30 minutes to 8 hours). Guests can only book inside those hours, in whole slots, and the server enforces it.
- **Availability calendar and day view.** The month view shows how many slots are open each day, or *Booked up* or *Closed*. Choosing a day lists its time slots as Open, Requested, Booked or Past. Guests select a slot, or a run of back-to-back slots, and send the request from the same panel. Visitors can browse open times, and hosts see who booked each slot. The public never sees who booked.
- **Host approval.** Requests start as *pending*. The host confirms or declines them from the Bookings page.
- **Cancel any time before it starts.** Either side can cancel. Bookings are never deleted, so both sides keep a record.
- **One Bookings page:** requests waiting for your reply come first, with Confirm and Decline on each card, then your upcoming bookings, what's coming up at your locations, and a folded-away history.
- **Light and dark themes**, keyboard-friendly, and laid out for phones.

## How bookings stay correct

- Times are stored as real timestamps.
- A location can't be double-booked. Pending and confirmed bookings hold their slot, and declined or cancelled ones free it again.
- The overlap check runs while holding a database row lock on the location, so two people submitting at the same moment can't both get the same slot.
- Bookings must be in the future, fall inside the host's hours on whole slots, and hosts can't book their own location.
- Times are in Central Time.

## Security

- **Authorization with Pundit:** only a location's host can edit or delete it. A booking is visible only to its guest and that location's host. Everything is denied unless a policy allows it.
- **CSRF protection** is on for every form.
- **No trusting form fields for ownership:** the signed-in user is always the guest or host. Hidden `guest_id` and `host_id` fields are ignored.
- **Secrets live in environment variables**, never in the code.
- **Uploaded photos** are limited to common image types and stored on Cloudinary, because Render's disk is wiped on each deploy.
- **Brakeman** scans every pull request for common Rails security problems.

## Tests

RSpec model, helper and request specs cover the booking rules, calendar labels, permissions, privacy and CSRF protection. On every pull request, GitHub Actions:

- runs the specs against PostgreSQL
- rehearses the production database migration on old-format data
- scans for security problems with Brakeman
- boots the app with sample data and publishes screenshots of the main pages to the `ci-screenshots` branch

```bash
bundle exec rspec
```

## Running it locally

Requirements: Ruby 3.4.12 (see `.ruby-version`) and PostgreSQL.

```bash
bundle install
bin/rails db:create db:migrate
bin/rails sample_data   # optional: sample hosts, guests, locations and bookings
bin/dev                 # or bin/rails server
```

Sample accounts use the password `password`, for example `host1@example.com` and `guest1@example.com`. **`bin/rails sample_data` deletes all existing users, locations and bookings first.**

## Configuration

Set these environment variables (on Render: the service's **Environment** page):

| Variable | What it's for |
| --- | --- |
| `DATABASE_URL` | PostgreSQL connection string |
| `SECRET_KEY_BASE` | Rails secret (Render generates it) |
| `CLOUDINARY_URL` | Photo storage, e.g. `cloudinary://KEY:SECRET@CLOUD_NAME` |
| `MAPBOX_ACCESS_TOKEN` | Maps on location pages |
| `WEB_RAKE_USERNAME` / `WEB_RAKE_PASSWORD` | Login for the admin task runner at `/rails/tasks` |

If `CLOUDINARY_URL` isn't set, photos are saved to local disk. That's fine for development, but on Render they disappear on each deploy.

## Data model

![Entity relationship diagram](erd.png)

- **User** — can host locations and book other people's locations.
- **Location** — belongs to a host, has a slot length, opening hours and many bookings.
- **OpeningHour** — one open day of the week for a location, with opening and closing times.
- **Booking** — belongs to a guest and a location, with a start, an end and a status (`pending`, `confirmed`, `declined` or `cancelled`).

## Deployment

Render runs `bin/render-build.sh` (install gems, precompile assets, migrate, re-upload any missing sample photos) and then `bin/render-start.sh`.
