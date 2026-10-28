class ImageUploader < CarrierWave::Uploader::Base
  # Render's disk is wiped on every deploy and restart, so in production photos
  # are stored on Cloudinary. Set CLOUDINARY_URL (from the Cloudinary dashboard)
  # in Render -> Environment. Without it (e.g. on your own computer) photos are
  # saved to public/uploads as before.
  if ENV["CLOUDINARY_URL"].present?
    include Cloudinary::CarrierWave
  else
    storage :file

    # Store uploads in a deterministic, app-owned path.
    def store_dir
      "uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
    end
  end

  # Restrict upload to common image types.
  def extension_allowlist
    %w[jpg jpeg gif png webp]
  end
end
