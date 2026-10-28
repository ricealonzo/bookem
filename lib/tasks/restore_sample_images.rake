desc "Re-upload sample location photos to Cloudinary and give locations with lost photos a stand-in (keeps all other data)"
task({ restore_sample_images: :environment }) do
  require Rails.root.join("db", "sample_data")

  # ONLY_MISSING=true (used by bin/render-build.sh) skips photos that are
  # already on Cloudinary, so deploys don't re-upload them every time.
  only_missing = ENV["ONLY_MISSING"] == "true"

  if ENV["CLOUDINARY_URL"].blank?
    if only_missing
      puts "CLOUDINARY_URL is not set; skipping photo restore."
      next
    end
    if Rails.env.production?
      puts "Warning: CLOUDINARY_URL is not set, so photos will be saved to the server's"
      puts "disk and disappear again on the next deploy or restart."
    end
  end

  restored = 0

  SampleData::LOCATIONS.each do |sample|
    locations = Location.where(name: sample[:name])

    if locations.empty?
      puts "Skipped #{sample[:name]}: no location with that name"
      next
    end

    locations.each do |location|
      # Photos already on Cloudinary are saved as "v<version>/<name>"; plain
      # file names are leftovers from the old disk storage.
      if only_missing && location.read_attribute(:image).to_s.include?("/")
        next
      end

      File.open(SampleData.sample_image_path(sample[:image_file])) do |file|
        location.image = file
        location.save!
      end
      restored += 1
      puts "Restored photo for #{location.name} (id #{location.id})"
    end
  end

  # Locations added through the site whose photo was lost with Render's disk
  # (still a plain file name, not on Cloudinary) get a stand-in sample photo.
  # Their owners can replace it from the location's edit page.
  sample_names = SampleData::LOCATIONS.map { |sample| sample[:name] }
  lost = []
  if ENV["CLOUDINARY_URL"].present?
    lost = Location.where.not(name: sample_names).where.not(image: [nil, ""]).select do |location|
      !location.read_attribute(:image).to_s.include?("/")
    end
  end

  lost.each do |location|
    File.open(SampleData.sample_image_path("event_space.jpg")) do |file|
      location.image = file
      location.save!
    end
    puts "Gave #{location.name} (id #{location.id}) a stand-in photo"
  end

  puts
  puts "Restored #{restored} sample photo(s) and #{lost.size} stand-in photo(s)."
end
