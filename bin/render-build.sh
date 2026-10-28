#!/usr/bin/env bash
# exit on error
set -o errexit

bundle install
bundle exec rake assets:precompile
bundle exec rake assets:clean
bundle exec rake db:migrate

# Re-upload any sample location photos that aren't on Cloudinary yet.
# A failure here shouldn't block the deploy.
ONLY_MISSING=true bundle exec rake restore_sample_images || echo "Photo restore failed; see the output above."
