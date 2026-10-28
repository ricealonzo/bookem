desc "Re-upload the sample location photos from db/sample_images (keeps all other data)"
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

  sample_names = SampleData::LOCATIONS.map { |sample| sample[:name] }
  others = Location.where.not(name: sample_names).where.not(image: [nil, ""])

  puts
  puts "Restored #{restored} sample photo(s)."
  if others.any?
    puts "These locations had photos uploaded through the site. Those files can't be"
    puts "recovered, so re-upload them from each location's edit page:"
    others.each { |location| puts "  - #{location.name} (id #{location.id})" }
  end
end
