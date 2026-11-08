# Path configuration for the iOS and Android apps.
#
# The apps read these rules to decide how to show each URL: forms slide up
# as modals, the home page resets the stack, and so on. Each app also ships
# a copy inside it (mobile/*/path-configuration.json) for its first launch,
# then downloads this one, so rules can change without an app store update.
class ConfigurationsController < ApplicationController
  # Pages opened as modals that slide up over the current screen.
  MODAL_PATTERNS = [
    "/new$",
    "/edit$",
    "/users/sign_in$",
    "/users/sign_up$",
    "/users/password/new$"
  ].freeze

  # GET /configurations/ios_v1.json
  def ios
    render json: { settings: {}, rules: shared_rules }
  end

  # GET /configurations/android_v1.json
  # Android also needs to know which screen type shows each URL; the web
  # screen built into Hotwire Native is hotwire://fragment/web.
  def android
    everything = {
      patterns: [ ".*" ],
      properties: { context: "default", uri: "hotwire://fragment/web", pull_to_refresh_enabled: true }
    }
    render json: { settings: {}, rules: [ everything ] + shared_rules }
  end

  private

  def shared_rules
    [
      {
        patterns: MODAL_PATTERNS,
        properties: { context: "modal", pull_to_refresh_enabled: false }
      },
      {
        patterns: [ "^/$", "^/locations$" ],
        properties: { presentation: "clear_all" }
      }
    ]
  end
end
