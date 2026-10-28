# Bookem

Bookem lets small businesses list a space (a studio, salon chair, event loft and so on) and lets customers request time there. Hosts confirm or decline each request, and both sides keep a record of every booking.

**Live site:** https://bookem-4pho.onrender.com

Built with Ruby 3.4 and Rails 8.1, PostgreSQL, Devise, Pundit, Stimulus and Cloudinary, and deployed on Render.

## Features

- **Browse locations** with photos, details and a map (Mapbox).
- **Availability calendar** shows each month at a glance, with today ringed, past days hatched, and taken times labeled *Booked* or *Requested*. Clicking a day fills in the booking form. On phones, taken times appear as dots with a list below. The public never sees who booked.
- **Request a booking** for a time range from the panel beside the location details.
- **Host approval.** Requests start as *pending*. The host confirms or declines them from the Bookings page.
- **Change or cancel.** Guests can change times while a request is pending, and either side can cancel before the booking starts. Bookings are never deleted.
- **One Bookings page:** requests waiting for your reply come first, with Confirm and Decline on each card, then your upcoming bookings, what's coming up at your locations, and a folded-away history.
- **Light and dark themes**, keyboard-friendly, and laid out for phones.

## How bookings stay correct

- Times are stored as real timestamps.
- A location can't be double-booked. Pending and confirmed bookings hold their slot, and declined or cancelled ones free it again.
- The overlap check runs while holding a database row lock on the location, so two people submitting at the same moment can't both get the same slot.
- Bookings must be in the future, end after they start, last no more than 30 days, and hosts can't book their own location.

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
- **Location** — belongs to a host and has many bookings.
- **Booking** — belongs to a guest and a location, with a start, an end and a status (`pending`, `confirmed`, `declined` or `cancelled`).

## Deployment

Render runs `bin/render-build.sh` (install gems, precompile assets, migrate, re-upload any missing sample photos) and then `bin/render-start.sh`.
