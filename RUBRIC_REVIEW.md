# SDF Final Project Rubric - Technical

- Date/Time: 2026-03-04
- Trainee Name: Alonzo Rice
- Project Name: BookEm
- Reviewer Name: Claude Code, Ian Heraty, Adolfo Nava
- Repository URL: <https://github.com/ricealonzo/bookem>
- Feedback Pull Request URL: <https://github.com/ricealonzo/bookem/pull/1>

---

## Readme (max: 10 points)

- [x] **Markdown**: Is the README formatted using Markdown?
  > Evidence: `README.md` line 1 uses a `#` header (`# BookEm`). Minimal but valid Markdown.

- [x] **Naming**: Is the repository name relevant to the project?
  > Evidence: Repository folder is `bookem`, project is a booking app called BookEm. Relevant and clear.

- [x] **1-liner**: Is there a 1-liner briefly describing the project?
  > Evidence: `README.md` line 2 — "A secure, user-friendly, and simple scheduling app tailored for small businesses to manage appointments without needing an in-house IT team."

- [ ] **Instructions**: Are there detailed setup and installation instructions, ensuring a new developer can get the project running locally without external help?
  > No setup instructions whatsoever. No `bundle install`, no database setup steps, no environment variable guidance.

- [ ] **Configuration**: Are configuration instructions provided, such as environment variables or configuration files that need to be set up?
  > No mention of required env vars (e.g., `MAPBOX_ACCESS_TOKEN`, `DATABASE_URL`, `SECRET_KEY_BASE`).

- [ ] **Contribution**: Are there clear contribution guidelines?
  > None present.

- [ ] **ERD**: Does the documentation include an entity relationship diagram?
  > `erd.png` exists at the repo root (64KB) but is not referenced or embedded in `README.md`.

- [ ] **Troubleshooting**: Is there an FAQs or Troubleshooting section?
  > None present.

- [ ] **Visual Aids**: Are there visual aids (screenshots, etc.)?
  > `erd.png` exists in repo but is not linked in the README. No screenshots.

- [ ] **API Documentation**: N/A — the project does not expose a public API.

### Score (3/10):

### Notes:
The README is effectively three lines. It identifies the project and provides a one-sentence description but nothing else. A new developer has no path to get this running. The `erd.png` file exists but is orphaned — it needs to be embedded in or linked from the README.

---

## Version Control (max: 10 points)

- [x] **Version Control**: Is the project using Git?
  > Evidence: `.git/` directory present; 45 commits in history.

- [x] **Repository Management**: Is the repository hosted on GitHub (or similar)?

- [ ] **Commit Quality**: Does the project have regular commits with clear, descriptive messages?
  > Commit history includes: `"ee"`, `"great"`, `"mvp"`, `"port"`, `"upday file"`, `"checking execution"`. These are not descriptive. Many commits do not explain what changed or why.

- [ ] **Pull Requests**: Does the project employ a clear branching and merging strategy?
  > All 45 commits are on `main`. No feature branches, no PRs, no evidence of Git Flow or any branching strategy.

- [ ] **Issues**: Is the project utilizing issue tracking?

- [ ] **Linked Issues**: Are issues linked to pull requests?

- [ ] **Project Board**: Does the project utilize a project board?

- [ ] **Code Review Process**: Is there evidence of a code review process?
  > No PRs means no code reviews. No evidence of peer or mentor review.

- [ ] **Branch Protection**: Are main branches protected?
  > Given all commits are directly to `main`, branch protection is likely not enabled.

- [ ] **Continuous Integration/Continuous Deployment (CI/CD)**: Has the project implemented CI/CD pipelines?
  > `.github/workflows/ci.yml` exists but **all real jobs are disabled**. The only active job is a placeholder: `run: 'echo "CI jobs disabled"'`. Brakeman, Rubocop, and importmap audit are all commented out.

### Score (2/10):

### Notes:
Points awarded only for using Git and GitHub hosting. Everything else is absent or disabled. All development occurred directly on `main` with no branching strategy, no pull requests, and no peer review. The CI pipeline exists structurally but is explicitly disabled. This is the most underdeveloped section in the project.

---

## Code Hygiene (max: 8 points)

- [x] **Indentation**: Is the code consistently indented?
  > Evidence: Controllers, models, and views follow consistent 2-space indentation throughout.

- [x] **Naming Conventions**: Are naming conventions clear and consistent?
  > Evidence: `set_location`, `booking_params`, `ended_at_not_before_started_at` — all snake_case, descriptive.

- [x] **Casing Conventions**: Are casing conventions consistent?
  > Evidence: Ruby classes use PascalCase (`LocationsController`, `ImageUploader`), methods/vars use snake_case, JavaScript uses camelCase. Conventions are respected.

- [x] **Layouts**: Is `application.html.erb` used effectively?
  > Evidence: `app/views/layouts/application.html.erb` provides the global navigation, flash messages, and page structure. Views render within `<%= yield %>`.

- [x] **Code Clarity**: Is the code easy to read?
  > Controllers are thin and readable. Model validations are clearly expressed. Overall structure is understandable.

- [ ] **Comment Quality**: Does code include meaningful inline comments explaining "why"?
  > Comments present are scaffold-generated boilerplate (`# GET /locations or /locations.json`, `# Use callbacks to share common setup...`). No comments explain non-obvious logic such as why `Time.zone.parse` is called on string datetime fields in the model and view.

- [ ] **Minimal Unused Code**: Is unused code deleted?
  > `Gemfile` includes gems that are installed but never used: `pundit` (no policies exist), `ransack` (never called), `kaminari` and `pagy` (no pagination implemented). CI jobs are commented out rather than removed or enabled. This is noise in the project.

- [x] **Linter**: Is a linter configured?
  > Evidence: `.rubocop.yml` exists and inherits from `rubocop-rails-omakase`. Custom overrides present for `HashSyntax`, `SpaceInsideParens`, and `EmptyLinesAroundBlockBody`.

### Score (5/8):

### Notes:
Solid on structural conventions. The linter is configured (though CI is disabled so it never runs automatically). Two deductions for unused gems/code lingering in the codebase and for scaffold-only comments.

---

## Patterns of Enterprise Applications (max: 10 points)

- [x] **Domain Driven Design**: Does the application follow domain-driven design principles?
  > Evidence: Controllers are thin. Business logic (associations, validations) lives in models. MVC separation is maintained at a basic level.

- [ ] **Advanced Data Modeling**: Has the application utilized ActiveRecord callbacks for model lifecycle management?
  > No `before_save`, `after_create`, `before_validation`, or any other callbacks exist in `app/models/`.

- [x] **Component-Based View Templates**: Does the application use partials to promote reusability?
  > Evidence: `app/views/bookings/_form.html.erb`, `app/views/locations/_form.html.erb`, `app/views/locations/_location.html.erb` — partials are used and rendered with `render`.

- [ ] **Backend Modules**: Does the application use modules/concerns?
  > `app/models/concerns/` and `app/controllers/concerns/` directories exist but contain no custom modules.

- [x] **Frontend Modules**: Does the application use ES6 modules?
  > Evidence: `app/javascript/controllers/` includes `hello_controller.js` and `modal_controller.js`, registered via `app/javascript/controllers/index.js` using Stimulus conventions.

- [ ] **Service Objects**: Does the application abstract logic into service objects?
  > No `app/services/` directory. No service objects.

- [ ] **Polymorphism**: Does the application use polymorphism?
  > None identified.

- [ ] **Event-Driven Architecture**: Does the application use pub-sub or ActionCable?
  > `solid_cable` is in the Gemfile and infrastructure tables exist in the schema, but ActionCable is not used in application code.

- [x] **Overall Separation of Concerns**: Are concerns separated effectively?
  > Evidence: Controllers delegate data retrieval to models, views are largely presentational. Deduction noted for business logic leaking into views (see Notes).

- [ ] **Overall DRY Principle**: Does the application follow DRY?
  > Notable DRY violations: `current_page?` checks in `bookings/_form.html.erb` (lines 15–27) to conditionally change layout and title — this is a view smelling of controller logic. `Time.zone.parse` is called both in `booking.rb` (model validation) and `locations/show.html.erb` (view, lines 75–76), duplicating parsing logic that belongs only in the model layer.

### Score (4/10):

### Notes:
The application demonstrates basic MVC separation and uses partials and Stimulus well. However, no callbacks, no concerns, no service objects, no polymorphism, and no event-driven architecture are present. The DRY violations in the booking form partial (using `current_page?` to branch layout and headings) are a code smell that should be refactored using separate partials or component arguments.

---

## Design (max: 5 points)

- [x] **Readability**: 
- [x] **Line length**: 
- [x] **Font Choices**:
- [x] **Consistency**:
- [x] **Double Your Whitespace**:

### Score (5/5):

### Notes:

From code inspection: Bootstrap 5.3.8 and Pico CSS (Zinc theme) are loaded via CDN. Custom CSS in `app/assets/stylesheets/location_show.css` includes media queries (`@media (max-width: 640px)`). Dark mode toggle with `localStorage` persistence is implemented in JavaScript

---

## Frontend (max: 10 points)

- [x] **Mobile/Tablet Design**: 
  > From code: `location_show.css` includes `@media (max-width: 640px)` breakpoints. Bootstrap's responsive grid is used.

- [x] **Desktop Design**:

- [x] **Styling**: Does the frontend use CSS or a CSS framework?
  > Evidence: Bootstrap 5.3.8 via CDN, Pico CSS via CDN, custom stylesheets in `app/assets/stylesheets/`. Bootstrap utility classes used throughout views.

- [x] **Semantic HTML**: Is semantic HTML used?
  > Evidence: `app/views/layouts/application.html.erb` uses `<header>`, `<nav>`, `<article>`, `<body>`. Not all views are fully semantic but the layout establishes the structure.

- [x] **Feedback**: Are flash messages implemented?
  > Evidence: Flash notice/alert rendered in `app/views/layouts/application.html.erb`. Controller actions pass `notice:` on redirects.

- [x] **Client-Side Interactivity**: Is JavaScript used for interactivity?
  > Evidence: Stimulus controllers (`modal_controller.js`, `hello_controller.js`), jQuery loaded, Turbo enabled, dark mode toggle in `application.js`.

- [ ] **AJAX**: Is AJAX used to perform a CRUD action and update the UI?
  > Mapbox uses `fetch()` for geocoding but this is not a CRUD operation against the app's own API. No AJAX-based create/update/delete of app resources.

- [ ] **Form Validation**: Does the project include client-side form validation?
  > No client-side validation found. Validation is server-side only.

- [ ] **Accessibility: alt tags**: Are alt tags implemented?
  > Image tags rendered via CarrierWave (`@location.image`) in `_location.html.erb` — alt text not confirmed present.

- [ ] **Accessibility: ARIA roles**: Are ARIA roles implemented?
  > None found in views reviewed.

### Score (6/10):

### Notes:
The frontend has good bones — Bootstrap framework, semantic layout, flash feedback, and Stimulus interactivity. However, there is no AJAX CRUD, no client-side validation, no confirmed alt text on images, and no ARIA roles. 

---

## Backend (max: 9 points)

- [x] **CRUD**: Does the application implement at least one resource with full CRUD functionality?
  > Evidence: `LocationsController` and `BookingsController` both implement full CRUD (index, show, new, create, edit, update, destroy).

- [x] **MVC pattern**: Does the application follow MVC with skinny controllers?
  > Evidence: Controllers are thin — `create` sets the resource and delegates to `save`. Validations and associations live in models. No direct database queries in views.

- [x] **RESTful Routes**: Are routes RESTful?
  > Evidence: `config/routes.rb` uses `resources :locations` and `resources :bookings`. Standard REST verbs and paths.

- [ ] **DRY queries**: Are database queries in the model layer?
  > Violation: `locations/show.html.erb` lines 75–76 call `Time.zone.parse(booking.started_at.to_s)` directly in the view — this parsing logic belongs in the model. Also, `LocationsController#show` calls `Location.find(params[:id])` directly (line 12) despite `set_location` already running via `before_action` (line 2), causing a redundant second query.

- [ ] **Data Model Design**: Is the data model well-designed and efficient?
  > **Critical Issue**: `db/schema.rb` defines `bookings.started_at` and `bookings.ended_at` as `:string` columns, not `:datetime`. Storing timestamps as strings in a scheduling/booking application is architecturally incorrect. Sorting, querying by date range, and timezone handling are all impaired.

- [x] **Associations**: Does the application use Rails associations effectively?
  > Evidence: `belongs_to :guest, class_name: "User", counter_cache: true`, `has_many :bookings, dependent: :destroy`, `has_one :host, through: :location`. Well-structured associations including counter caches.

- [x] **Validations**: Are validations implemented?
  > Evidence: Location validates presence of name, address, city, state, postal_code. Booking validates presence of started_at, ended_at, location_id, guest_id, plus custom `ended_at_not_before_started_at` validation in `booking.rb`.

- [ ] **Query Optimization**: Does the application use scopes?
  > No scopes defined in any model.

- [x] **Database Management**: Are rake tasks or CSV upload included?
  > Evidence: `lib/tasks/sample_data.rake` generates 10 hosts, 20 guests, 50 bookings using Faker with realistic location data.

### Score (6/9):

### Notes:
Full CRUD, RESTful routes, meaningful associations, and a sample data rake task are all strong. Two critical deductions: datetime columns stored as strings (fundamental schema error) and no query scopes. The double-query in `LocationsController#show` and view-layer date parsing are maintainability concerns.

---

## Quality Assurance and Testing (max: 2 points)

- [ ] **End to End Test Plan**: Does the project include an E2E test plan?
  > None found. No test plan document or feature spec outline.

- [ ] **Automated Testing**: Does the project include a meaningful test suite?
  > `spec/` directory exists with RSpec infrastructure fully configured (`spec/rails_helper.rb` includes Capybara, Shoulda Matchers, Devise helpers, Selenium WebDriver). However, the only test file is `spec/sample_spec.rb`, which contains a single placeholder: `it "is not graded"`. No model, controller, feature, or integration specs exist.

### Score (0/2):

### Notes:
The test infrastructure is properly configured — RSpec, Capybara, Shoulda Matchers are all set up correctly. This is promising but the actual test suite is empty. Zero credit must be given as no meaningful tests exist.

---

## Security and Authorization (max: 5 points)

- [ ] **Credentials**: Are API keys and sensitive information securely stored?
  > **Critical Failure**: `config/initializers/web_rake.rb` contains hardcoded plaintext credentials:
  > ```ruby
  > config.username = 'Loveis1988'
  > config.password = 'Loveis1988'
  > ```
  > This file is committed to version control. `.env` files are properly gitignored, but this initializer bypasses that protection entirely.

- [x] **HTTPS**: Is HTTPS enforced?
  > Evidence: `config/environments/production.rb` — `config.force_ssl = true` and `config.assume_ssl = true`.

- [ ] **Sensitive attributes**: Are sensitive attributes set server-side rather than through hidden fields?
  > `app/views/bookings/_form.html.erb` line 44: `<%= form.hidden_field :guest_id, value: booking.guest_id %>`. The `guest_id` is also permitted in `booking_params` (`bookings_controller.rb` line 70). While the controller does override this with `@booking.guest = current_user`, including `guest_id` in both the form's hidden field and strong params is insecure by design. A malicious request bypassing the form could exploit this pattern if the override is ever removed or skipped.

- [x] **Strong Params**: Are strong parameters used?
  > Evidence: Both controllers use Rails 8 `params.expect()` syntax. `location_params` does not include `:host_id` (correct). `booking_params` includes `:guest_id` which should not be there (see above), but strong params are present.

- [ ] **Authorization**: Is an authorization framework employed?
  > `pundit` is in `Gemfile` and installed. However, **no Pundit policies exist** (`app/policies/` directory does not exist). No authorization checks are present. Any authenticated user can edit or destroy any other user's location:
  > ```ruby
  > # locations_controller.rb line 3
  > before_action :authenticate_user!, only: [:new, :edit, :update, :destroy]
  > # No ownership check — any logged-in user can edit/destroy any location
  > ```

### Score (2/5):

### Notes:
Two critical security failures:
1. **Hardcoded credentials in an initializer committed to git** — this must be remediated immediately using Rails credentials or environment variables.
2. **No authorization** — authentication (Devise) is present but authorization (who can do what) is completely missing. Any logged-in user can edit or delete any other user's locations and bookings.

---

## Features (each: 1 point - max: 15 points)

- [ ] **Sending Email**: Does the application send transactional emails?
  > `app/mailers/user_mailer.rb` exists with a `test` method skeleton. No transactional emails (welcome, booking confirmation, etc.) are implemented.

- [ ] **Sending SMS**
  > None.

- [ ] **Building for Mobile (PWA)**
  > None.

- [ ] **Advanced Search and Filtering**
  > `ransack` is in `Gemfile` but never used in any controller or view.

- [ ] **Data Visualization**
  > None.

- [ ] **Dynamic Meta Tags**
  > None.

- [ ] **Pagination**
  > `kaminari` and `pagy` are both in `Gemfile` but neither is used. `Location.all` and `Booking.all` are returned without pagination.

- [ ] **Internationalization (i18n)**
  > None.

- [ ] **Admin Dashboard**
  > None.

- [ ] **Business Insights Dashboard**
  > None.

- [ ] **Enhanced Navigation (breadcrumbs)**
  > None.

- [ ] **Performance Optimization (Bullet gem)**
  > `bullet` gem not in `Gemfile`.

- [x] **Stimulus**
  > Evidence: `app/javascript/controllers/modal_controller.js` and `hello_controller.js` registered via `app/javascript/controllers/index.js`. Stimulus is properly wired.

- [x] **Turbo Frames**
  > Evidence: `app/views/locations/show.html.erb` lines 69–94 use `turbo_frame_tag "bookings_calendar"` to render a calendar that can update without full page reload.

- [x] **Other**: Dark mode with `localStorage` persistence.
  > Evidence: `app/javascript/application.js` implements a theme toggle that reads/writes `localStorage` and applies `data-theme` attribute. This is a meaningful UX enhancement.

### Score (3/15):

### Notes:
Three features implemented: Stimulus, Turbo Frames, and a dark mode toggle. Multiple gems are installed but unused (Ransack, Kaminari, Pagy). The mailer scaffold exists but sends nothing. Significant gap between installed tooling and actually implemented features.

---

## Ambitious Features (each: 2 points - max: 16 points)

- [ ] **Receiving Email (ActionMailbox)**
  > None.

- [ ] **Inbound SMS**
  > None.

- [ ] **Web Scraping Capabilities**
  > `web_rake` gem is installed and `config/initializers/web_rake.rb` configures it. Recent commit history shows active work on this (`"created initializer for rake_web"`, `"checking execution"`, `"updated web_rake.rb"`). However:
  > 1. No rake task or service invoking `WebRake` is found in `lib/tasks/`
  > 2. The credentials are hardcoded (security violation, see Security section)

- [ ] **Background Processing (ActiveJob)**
  > `solid_queue` infrastructure is in the schema. `app/jobs/application_job.rb` exists as a base class. No custom jobs are implemented.

- [x] **Mapping and Geolocation**
  > Evidence: `app/views/locations/show.html.erb` lines 23–61 — Mapbox GL JS is loaded, a geocoding API call fetches coordinates for the location's address, and an interactive map with a marker is rendered. Meets the rubric criterion of "mapping or geocoding libraries (e.g., Mapbox, Geocoder)".

- [ ] **Cloud Storage Integration**
  > `cloudinary` gem is in `Gemfile`. `app/uploaders/image_uploader.rb` uses `:file` storage (not Cloudinary). Cloud storage is not actually implemented.

- [ ] **Chat GPT or AI Integration**
  > None.

- [ ] **Payment Processing**
  > None.

- [ ] **OAuth**
  > None.

- [ ] **Other**
  > None.

### Score (2/16):

### Notes:
Mapbox geolocation earns 2 points. Web scraping is unverified and has a critical security issue. Cloud storage and background jobs have infrastructure but no implementation.

---

## Technical Score (/100):
- Readme (3/10)
- Version Control (2/10)
- Code Hygiene (5/8)
- Patterns of Enterprise Applications (4/10)
- Design (5/5)
- Frontend (6/10)
- Backend (6/9)
- Quality Assurance and Testing (0/2)
- Security and Authorization (2/5)
- Features (3/15)
- Ambitious Features (2/16)
---
- **Total: 38/100**
---

## Additional Overall Comments

BookEm demonstrates a functional MVP — a user can register, create a location, and book it. The core Rails conventions are understood: thin controllers, model validations, RESTful routes, and Devise authentication are all present and functional. The Mapbox integration and dark mode show creative ambition.

The core issues are:

1. **No authorization** — any logged-in user can edit or destroy any other user's data. This is not a polish issue; it is a fundamental security vulnerability in a multi-user application.

2. **Hardcoded credentials committed to git** — `config/initializers/web_rake.rb` contains a plaintext password. This must be rotated and moved to environment variables immediately.

3. **No tests** — The spec infrastructure is correctly configured, which shows the intent, but zero meaningful tests were written. For a booking app, at minimum, model validations and controller authorization should be tested.

4. **No branching / no PRs / CI disabled** — All commits to `main` directly, no peer review, CI pipeline explicitly disabled. The version control section reflects a solo development sprint rather than a professional workflow.

5. **String columns for datetime** — `bookings.started_at` and `bookings.ended_at` stored as `:string` is a schema-level error. Temporal queries, sorting, and range lookups are broken by design. The workarounds in the model (`Time.zone.parse`) and views confirm this is a known workaround rather than an intentional choice.

The installed-but-unused gems (Pundit, Ransack, Kaminari/Pagy) suggest ambitious plans that were not executed. The remaining time before project submission should be focused on security (authorization + credential rotation) and a basic test suite.
