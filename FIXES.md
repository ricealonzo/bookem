# Prioritized Improvement Plan — BookEm

## P0 — Critical: Security / Architecture / Broken Patterns

These issues must be fixed before the project can be considered functional or safe.

---

### P0-1: Hardcoded Credentials in Version-Controlled Initializer

- **File**: `config/initializers/web_rake.rb`
- **Problem**: Plaintext username and password (`'Loveis1988'`) are committed to git. Anyone with repository access has these credentials. Rotating them after the fact does not remove them from git history without a rewrite.
- **Suggested Solution**: Move credentials to Rails encrypted credentials or environment variables.

```ruby
# config/initializers/web_rake.rb — after fix
WebRake.configure do |config|
  config.username = ENV.fetch("WEB_RAKE_USERNAME")
  config.password = ENV.fetch("WEB_RAKE_PASSWORD")
end
```

Then add to `.env` (already gitignored):
```
WEB_RAKE_USERNAME=your_username
WEB_RAKE_PASSWORD=your_password
```

Also rotate the exposed credentials in whatever service `web_rake` connects to.

---

### P0-2: No Authorization — Any User Can Edit or Destroy Any Resource

- **File**: `app/controllers/locations_controller.rb` (lines 3, 43, 57), `app/controllers/bookings_controller.rb` (lines 41, 54)
- **Problem**: `authenticate_user!` confirms a user is logged in, but there is no check that the current user *owns* the resource they are modifying. Any authenticated user can `PATCH /locations/1` or `DELETE /bookings/5` regardless of ownership.
- **Suggested Solution**: Implement Pundit policies (gem is already installed).

```ruby
# app/policies/location_policy.rb
class LocationPolicy < ApplicationPolicy
  def edit?   = record.host == user
  def update? = record.host == user
  def destroy? = record.host == user
end

# app/policies/booking_policy.rb
class BookingPolicy < ApplicationPolicy
  def show?    = record.guest == user || record.host == user
  def edit?    = record.guest == user
  def update?  = record.guest == user
  def destroy? = record.guest == user
end
```

```ruby
# app/controllers/application_controller.rb — add:
include Pundit::Authorization
after_action :verify_authorized, except: :index
after_action :verify_policy_scoped, only: :index
rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

private
def user_not_authorized
  flash[:alert] = "You are not authorized to perform this action."
  redirect_back(fallback_location: root_path)
end
```

```ruby
# In LocationsController#update, #destroy:
authorize @location
# In BookingsController#show, #edit, #update, #destroy:
authorize @booking
```

---

### P0-3: `skip_forgery_protection` Disables CSRF Protection

- **File**: `app/controllers/application_controller.rb` (line 2)
- **Problem**: `skip_forgery_protection` disables Rails' built-in CSRF token validation across the **entire application**. This removes protection against cross-site request forgery attacks for every form and mutation.
- **Suggested Solution**: Remove this line entirely. Rails generates and validates CSRF tokens automatically with standard Devise forms. If this was added to fix a specific error (e.g., Turbo form submissions), use the proper Turbo-compatible approach instead.

```ruby
# app/controllers/application_controller.rb — remove line 2:
# skip_forgery_protection   ← DELETE THIS LINE
```

If Turbo was causing `InvalidAuthenticityToken` errors, ensure `<%= csrf_meta_tags %>` is in the layout (it is) and that forms use `form_with` (they do). No further changes needed.

---

### P0-4: Booking Timestamps Stored as String Instead of Datetime

- **File**: `db/schema.rb` (lines 18–19), `app/models/booking.rb`, `app/views/locations/show.html.erb`
- **Problem**: `bookings.started_at` and `bookings.ended_at` are `:string` columns. A booking/scheduling application needs temporal columns for sorting, range queries, and calendar integration. The string type forces brittle `Time.zone.parse` workarounds in both the model validation and the view.
- **Suggested Solution**: Generate a migration to change column types.

```bash
rails generate migration ChangeBookingTimestampsToDatetime
```

```ruby
# db/migrate/TIMESTAMP_change_booking_timestamps_to_datetime.rb
class ChangeBookingTimestampsToDatetime < ActiveRecord::Migration[8.0]
  def up
    change_column :bookings, :started_at, :datetime
    change_column :bookings, :ended_at, :datetime
  end

  def down
    change_column :bookings, :started_at, :string
    change_column :bookings, :ended_at, :string
  end
end
```

After migrating, update `booking.rb` — the custom validation simplifies to:
```ruby
def ended_at_not_before_started_at
  return if started_at.blank? || ended_at.blank?
  errors.add(:ended_at, "cannot be before start time") if ended_at < started_at
end
```

And remove `Time.zone.parse` calls from `app/views/locations/show.html.erb` lines 75–76.

---

### P0-5: `guest_id` in Strong Params and Hidden Field

- **File**: `app/controllers/bookings_controller.rb` (line 70), `app/views/bookings/_form.html.erb` (line 44)
- **Problem**: `:guest_id` is permitted in `booking_params`. While the controller currently overrides it with `@booking.guest = current_user`, this is fragile — a future refactor could remove the override, reinstating the vulnerability. The hidden field in the form is also misleading.
- **Suggested Solution**: Remove `:guest_id` from strong params and the hidden field from the form.

```ruby
# bookings_controller.rb
def booking_params
  params.expect(booking: [:started_at, :ended_at, :location_id])
  # guest_id removed — guest is always set from current_user in #create
end
```

```erb
<%# bookings/_form.html.erb — remove line 44: %>
<%# <%= form.hidden_field :guest_id, value: booking.guest_id %> ← DELETE %>
```

---

## P1 — Important: Maintainability / Convention / Cleanliness

---

### P1-1: No Tests

- **File**: `spec/` (entire directory has only `spec/sample_spec.rb` with `it "is not graded"`)
- **Problem**: Zero meaningful automated tests. The RSpec infrastructure is correctly configured with Capybara, Shoulda Matchers, and Devise helpers.
- **Suggested Solution**: Write at minimum:

```ruby
# spec/models/booking_spec.rb
RSpec.describe Booking, type: :model do
  it { should validate_presence_of(:started_at) }
  it { should validate_presence_of(:ended_at) }
  it { should belong_to(:guest).class_name("User") }
  it { should belong_to(:location) }

  describe "ended_at_not_before_started_at" do
    let(:location) { create(:location) }
    let(:guest)    { create(:user) }

    it "is invalid when ended_at is before started_at" do
      booking = Booking.new(
        started_at: 1.hour.from_now,
        ended_at: Time.current,
        location: location,
        guest: guest
      )
      expect(booking).not_to be_valid
      expect(booking.errors[:ended_at]).to include("cannot be before start time")
    end
  end
end
```

Priority specs: Booking validation, Location validation, LocationsController authorization (ensure non-owner cannot edit).

---

### P1-2: CI Pipeline Is Disabled

- **File**: `.github/workflows/ci.yml`
- **Problem**: All real CI jobs (Brakeman, Rubocop, RSpec) are commented out. The only active job prints `"CI jobs disabled"`. CI provides no value in this state.
- **Suggested Solution**: Uncomment the existing jobs and add an RSpec job.

```yaml
# .github/workflows/ci.yml — uncomment scan_ruby, scan_js, lint
# Add:
test:
  runs-on: ubuntu-latest
  services:
    postgres:
      image: postgres:16
      env:
        POSTGRES_USER: postgres
        POSTGRES_PASSWORD: password
      ports: ['5432:5432']
      options: --health-cmd pg_isready --health-interval 10s --health-timeout 5s --health-retries 5
  steps:
    - uses: actions/checkout@v4
    - uses: ruby/setup-ruby@v1
      with:
        ruby-version: .ruby-version
        bundler-cache: true
    - run: bin/rails db:test:prepare
      env:
        DATABASE_URL: postgres://postgres:password@localhost:5432
    - run: bundle exec rspec
      env:
        DATABASE_URL: postgres://postgres:password@localhost:5432
```

---

### P1-3: No Branching Strategy / No Pull Requests

- **Problem**: All 45 commits went directly to `main`. Professional development requires feature branches and pull requests for code review.
- **Suggested Solution**: For remaining work, use a branching strategy:

```bash
git checkout -b fix/authorization
# ... make changes ...
git push origin fix/authorization
gh pr create --title "Add Pundit authorization to locations and bookings"
```

Enable branch protection on `main` in GitHub Settings → Branches → Add rule:
- Require pull request reviews before merging
- Require status checks to pass (once CI is re-enabled)

---

### P1-4: Double Query in `LocationsController#show`

- **File**: `app/controllers/locations_controller.rb` (lines 2, 12)
- **Problem**: `before_action :set_location` runs `Location.find(params.expect(:id))` for the `show` action (line 68). Then `show` calls `Location.find(params[:id])` again (line 12), causing two identical queries.

```ruby
def show
  @location = Location.find(params[:id])  # ← redundant; @location already set by set_location
  @bookings = @location.bookings
  @booking = Booking.new(location: @location, guest: current_user)
end
```

- **Suggested Solution**:

```ruby
def show
  # @location already set by before_action :set_location
  @bookings = @location.bookings
  @booking = Booking.new(location: @location, guest: current_user)
end
```

---

### P1-5: Business Logic in View — `Time.zone.parse` in `show.html.erb`

- **File**: `app/views/locations/show.html.erb` (lines 75–76)
- **Problem**: Date parsing logic lives in the view. This is a separation of concerns violation.

```erb
<% started_at = booking.started_at.present? ? Time.zone.parse(booking.started_at.to_s) : nil %>
<% ended_at = booking.ended_at.present? ? Time.zone.parse(booking.ended_at.to_s) : nil %>
```

- **Suggested Solution**: After fixing P0-4 (changing to datetime columns), this code is unnecessary. If string columns must remain temporarily, add a method to the Booking model:

```ruby
# app/models/booking.rb
def parsed_started_at
  started_at.present? ? Time.zone.parse(started_at.to_s) : nil
end

def parsed_ended_at
  ended_at.present? ? Time.zone.parse(ended_at.to_s) : nil
end
```

---

### P1-6: `current_page?` Branching in View Partial is a Code Smell

- **File**: `app/views/bookings/_form.html.erb` (lines 15–28)
- **Problem**: A partial checking `current_page?` to change its heading and container width is a design smell. The partial is aware of its rendering context, which breaks encapsulation.

```erb
<% if current_page?(controller: 'bookings', action: 'new') %>
  <div class="container-fluid" style="width:500px" >
<% elsif current_page?(controller: 'locations', action: 'show')  %>
  <div class="container-fluid" style="width:380px;" >
<% end %>
```

- **Suggested Solution**: Pass configuration via locals.

```erb
<%# In locations/show.html.erb: %>
<%= render "bookings/form", booking: @booking, title: "Book Now", container_class: "booking-form-compact" %>

<%# In bookings/new.html.erb: %>
<%= render "bookings/form", booking: @booking, title: "Create Booking", container_class: "booking-form-full" %>

<%# In bookings/_form.html.erb: %>
<div class="container-fluid <%= local_assigns[:container_class] %>">
  <h2><%= local_assigns.fetch(:title, "Edit Booking") %></h2>
  ...
```

---

### P1-7: Unused Gems Should Be Removed or Implemented

- **File**: `Gemfile`
- **Problem**: The following gems are installed but never used in application code:
  - `pundit` — no policies exist
  - `ransack` — never called in controllers/views
  - `kaminari` — never applied to queries
  - `pagy` — never applied to queries
- **Suggested Solution**: Either implement these features (see P2) or remove them from `Gemfile` and run `bundle install` to remove from `Gemfile.lock`. Unused gems increase attack surface and dependency maintenance burden.

---

### P1-8: README Is Effectively Empty

- **File**: `README.md`
- **Problem**: 3 lines of content. A new developer has no path to run this project.
- **Suggested Solution**: Add at minimum:

```markdown
## Setup

1. Clone the repository
2. `bundle install`
3. Copy `.env.example` to `.env` and fill in values (see Configuration section)
4. `rails db:create db:migrate`
5. `rails db:seed` or `rails sample_data:load` for sample data
6. `rails server`

## Configuration

Required environment variables (add to `.env`):
- `MAPBOX_ACCESS_TOKEN` — from mapbox.com
- `DATABASE_URL` — PostgreSQL connection string (auto-set on Render)
- `SECRET_KEY_BASE` — auto-generated on Render
- `WEB_RAKE_USERNAME` / `WEB_RAKE_PASSWORD` — credentials for WebRake

## ERD

![Entity Relationship Diagram](erd.png)
```

---

## P2 — Polish / UX / Enhancements

---

### P2-1: Implement Pagination

- **File**: `app/controllers/locations_controller.rb` (line 7), `app/controllers/bookings_controller.rb` (line 7)
- **Problem**: `Location.all` and `Booking.all` with no limit. Will degrade on real data.
- **Suggested Solution** (Kaminari already installed):

```ruby
# locations_controller.rb
@locations = Location.all.page(params[:page]).per(12)

# bookings_controller.rb
@bookings = current_user.bookings.page(params[:page]).per(20)
```

---

### P2-2: Scope Bookings Index to Current User

- **File**: `app/controllers/bookings_controller.rb` (line 7)
- **Problem**: `Booking.all` returns every booking from every user.
- **Suggested Solution**:

```ruby
def index
  @bookings = current_user.bookings  # guest bookings
  # Or: @bookings = current_user.locations.flat_map(&:bookings) for host view
end
```

---

### P2-3: Add Alt Text to Location Images

- **File**: `app/views/locations/_location.html.erb` (image tag)
- **Problem**: Images rendered via CarrierWave may lack descriptive `alt` text.
- **Suggested Solution**:

```erb
<%= image_tag location.image.url, alt: "Photo of #{location.name}" if location.image.present? %>
```

---

### P2-4: Move Inline `<script>` Block to a Stimulus Controller

- **File**: `app/views/locations/show.html.erb` (lines 23–61)
- **Problem**: 39 lines of JavaScript live directly in a view partial. This defeats Stimulus conventions and makes testing impossible.
- **Suggested Solution**: Extract to `app/javascript/controllers/map_controller.js`:

```javascript
// app/javascript/controllers/map_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { token: String, address: String }

  connect() {
    if (!this.tokenValue || !this.addressValue) {
      this.element.innerHTML = "<p>Map is unavailable.</p>"
      return
    }
    mapboxgl.accessToken = this.tokenValue
    // ... geocode and render map
  }
}
```

```erb
<%# In show.html.erb, replace <script> block with: %>
<div id="map" class="location-map"
     data-controller="map"
     data-map-token-value="<%= ENV.fetch('MAPBOX_ACCESS_TOKEN', '') %>"
     data-map-address-value="<%= full_address %>">
</div>
```

---

### P2-5: Flash Messages Should Use Styled Partials

- **File**: `app/views/layouts/application.html.erb`
- **Problem**: Flash alerts rendered without dismissal button or distinct styling per type (notice vs. alert).
- **Suggested Solution**: Create `app/views/shared/_flash.html.erb`:

```erb
<% flash.each do |type, message| %>
  <div class="alert alert-<%= type == 'notice' ? 'success' : 'danger' %> alert-dismissible fade show" role="alert">
    <%= message %>
    <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
  </div>
<% end %>
```

---

### P2-6: Inline Styles Should Be Replaced with CSS Classes

- **File**: `app/views/bookings/_form.html.erb` (lines 3, 16, 18, 30, 35)
- **Problem**: `style="color: red"`, `style="width:500px"`, `style="width:380px"`, `style="display: block"` are inline. This conflicts with dark mode, is not responsive, and cannot be overridden by the stylesheet.
- **Suggested Solution**: Move to `app/assets/stylesheets/`:

```css
.error-messages { color: var(--error-color, red); }
.booking-form-full { max-width: 500px; }
.booking-form-compact { max-width: 380px; }
.form-label { display: block; }
```

---

### P2-7: Add ARIA Roles for Accessibility

- **File**: `app/views/layouts/application.html.erb`, navigation and main content areas
- **Problem**: No ARIA roles present.
- **Suggested Solution**:

```erb
<nav aria-label="Main navigation">...</nav>
<main id="main-content" role="main">
  <%= yield %>
</main>
```

---

### P2-8: Implement Transactional Emails

- **File**: `app/mailers/user_mailer.rb`
- **Problem**: Mailer exists with a `test` method only. A booking app should confirm bookings via email.
- **Suggested Solution**:

```ruby
# app/mailers/user_mailer.rb
def booking_confirmation(booking)
  @booking = booking
  mail(
    to: booking.guest.email,
    subject: "Your booking at #{booking.location.name} is confirmed"
  )
end
```

Call in `BookingsController#create` after `@booking.save`:
```ruby
UserMailer.booking_confirmation(@booking).deliver_later
```

---

*End of FIXES.md*
