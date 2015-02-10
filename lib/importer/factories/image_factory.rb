require_relative './object_factory'

class ImageFactory < ObjectFactory

  def run
    if Image.exists?(attributes[:id])
      image = Image.find(attributes[:id])
      image.update(attributes.except(:id, :files, :collection))
      puts "  Updated. #{attributes[:id]}"
    else
      image = create_image
      puts "  Created #{image.id}" if image
    end

    add_image_to_collection(image, attributes)
    image
  end

  def create_image
    Image.create(attributes.except(:files, :collection)).tap do |image|
      attributes[:files].each do |file_path|
        create_file(image, file_path)
      end
    end
  end

  def create_file(image, file_name)
    path = image_path(file_name)
    unless File.exists?(path)
      puts "  * File doesn't exist at #{path}"
      return
    end
    image.generic_files.create do |gf|
      puts "  Reading image #{file_name}"
      gf.original.mime_type = mime_type(path)
      gf.original.original_name = File.basename(path)
      gf.original.content = File.new(path)
      gf.save!
    end
  end

  def mime_type(file_name)
    mime_types = MIME::Types.of(file_name)
    mime_types.empty? ? "application/octet-stream" : mime_types.first.content_type
  end

  def image_path(file_name)
    File.join(files_directory, file_name)
  end

  def add_image_to_collection(image, attrs)
    id = attrs[:collection][:id]

    coll = if Collection.exists?(id)
             Collection.find(id)
           else
             Collection.create(attrs[:collection])
           end

    coll.members << image
    coll.save
  end

end
