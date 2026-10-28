# config/initializers/web_rake.rb
#
# WebRake serves a page at /rails/tasks that can run rake tasks on the live
# site, protected by HTTP basic auth. Credentials come from the environment
# (set them in Render -> Environment):
#
#   WEB_RAKE_USERNAME
#   WEB_RAKE_PASSWORD
#
# If either is missing, the gem would fall back to admin/password, so we lock
# the page with random credentials instead (nobody can log in until they're set).

username = ENV["WEB_RAKE_USERNAME"].presence
password = ENV["WEB_RAKE_PASSWORD"].presence

WebRake.configure do |config|
  if username && password
    config.username = username
    config.password = password
  else
    config.username = SecureRandom.hex(32)
    config.password = SecureRandom.hex(32)
  end
end
