require "rails_helper"

RSpec.describe "Pages for the mobile apps", type: :request do
  let(:user) { create_user }
  let(:app_agent) { "Bookem iOS; Hotwire Native iOS; Turbo Native iOS; Mozilla/5.0 (iPhone)" }

  describe "inside the app" do
    it "hides the web header and footer, since the app has its own tab bar" do
      get root_path, headers: { "User-Agent" => app_agent }

      expect(response.body).to include(%(class="native-app"))
      expect(response.body).not_to include("site-header")
      expect(response.body).not_to include("site-footer")
    end

    it "keeps page titles short for the app's top bar" do
      get privacy_path, headers: { "User-Agent" => app_agent }
      expect(response.body).to include("<title>Privacy</title>")
    end

    it "shows the full site in a normal browser" do
      get root_path, headers: { "User-Agent" => "Mozilla/5.0 (iPhone) Safari" }

      expect(response.body).to include("site-header")
      expect(response.body).not_to include(%(class="native-app"))
    end
  end

  describe "the Account tab" do
    it "offers log in and sign up to visitors" do
      get account_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(new_user_session_path, new_user_registration_path)
    end

    it "lists the signed-in user's links and locations" do
      location = create_location(host: user, name: "Fade Factory")
      sign_in user
      get account_path

      expect(response.body).to include(user.email, "Fade Factory", location_path(location), "Sign out", edit_user_registration_path)
    end
  end

  describe "the privacy page" do
    it "explains what's collected and how to delete an account" do
      get privacy_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("What we collect", "Deleting your account", edit_user_registration_path)
    end
  end

  describe "path configuration" do
    it "tells iOS to show forms as modals" do
      get "/configurations/ios_v1.json"
      rules = response.parsed_body["rules"]

      modal = rules.detect { |rule| rule.dig("properties", "context") == "modal" }
      expect(modal["patterns"]).to include("/new$", "/users/sign_in$")
    end

    it "tells Android which screen shows web pages" do
      get "/configurations/android_v1.json"
      first = response.parsed_body["rules"].first

      expect(first["patterns"]).to eq([ ".*" ])
      expect(first.dig("properties", "uri")).to eq("hotwire://fragment/web")
    end

    it "matches the copies bundled inside the apps" do
      get "/configurations/ios_v1.json"
      ios = response.parsed_body
      get "/configurations/android_v1.json"
      android = response.parsed_body

      expect(JSON.parse(Rails.root.join("mobile/ios/Bookem/path-configuration.json").read)).to eq(ios)
      expect(JSON.parse(Rails.root.join("mobile/android/app/src/main/assets/json/path-configuration.json").read)).to eq(android)
    end
  end
end
