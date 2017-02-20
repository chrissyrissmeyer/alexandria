# frozen_string_literal: true
require "csv"
require File.expand_path("../factory", __FILE__)

# Import CSV files

module Importer::CSV
  include Importer::ImportLogger

  # Match headers like "lc_subject_type"
  TYPE_HEADER_PATTERN = /\A.*_type\Z/

  # The method called by bin/ingest
  # @param [Array] meta
  # @param [Array] data
  # @param [Hash] options See the options specified with Trollop in {bin/ingest}
  # @return [Int] The number of records ingested
  def self.import(meta, data, options)
    parse_log_options(options)

    logger.debug "Starting import with options #{options.inspect}"

    ingests = 0

    meta.each do |m|
      logger.info "Importing file #{m}"
      head, tail = split(m)

      if options[:skip] >= tail.length
        raise ArgumentError,
              "Number of records skipped (#{options[:skip]}) greater than total records to ingest"
      end

      tail.each do |row|
        attrs = csv_attributes(head, row)

        if options[:skip] > ingests
          logger.info "Skipping record #{ingests}: accession number #{attrs[:accession_number].first}"
          ingests += 1
          next
        end
        next if options[:number] && options[:number] <= ingests

        start_record = Time.now

        logger.info "Ingesting record #{ingests}: accession number #{attrs[:accession_number].first}"

        files = if attrs[:files].nil?
                  []
                else
                  data.select { |d| attrs[:files].include? File.basename(d) }
                end

        if options[:verbose]
          puts "Object attributes for item #{ingests + 1}:"
          puts attrs.each { |k, v| puts "#{k}: #{v}" }
          puts "Associated files for item #{ingests + 1}:"
          puts files.each { |f| puts f }
        end

        attrs = Importer::CSV.assign_access_policy(attrs)
        attrs = Importer::CSV.transform_coordinates_to_dcmi_box(attrs)
        attrs = Importer::CSV.handle_structural_metadata(attrs)

        model = Importer::CSV.determine_model(attrs.delete(:type))
        raise NoModelError if model.nil? || model.empty?

        o = ::Importer::Factory.for(model).new(attrs, files).run
        end_record = Time.now
        logger.info "accession_number #{attrs[:accession_number].first} ingested as #{o.id} in #{end_record - start_record} seconds (#{ingests + 1}/#{tail.length})"
        ingests += 1
      end
    end
    ingests
  rescue => e
    puts e
    puts e.backtrace
    raise IngestError, reached: ingests
  rescue Interrupt
    puts "\nIngest stopped, cleaning up..."
    raise IngestError, reached: ingests
  end

  # Given a 'type' field from the CSV, determine which object model pertains
  # @param [String] csv_type_field
  # @return [String] the name of the model class
  def self.determine_model(csv_type_field)
    csv_type_field.titleize.gsub(/\s+/, "")
  end

  # Read in a CSV file and split it into nested arrays.
  # Check for character encoding problems.
  # @param [String, Pathname] metadata
  # @return [Array]
  def self.split(metadata)
    csv = nil
    begin
      csv = ::CSV.read(metadata, encoding: "UTF-8")
    rescue ArgumentError => e # Most likely this is "invalid byte sequence in UTF-8"
      logger.error "The file #{metadata} could not be read in UTF-8. The error was: #{e}. Trying ISO-8859-1"
      csv = ::CSV.read(metadata, encoding: "ISO-8859-1")
    rescue => e
      logger.error "Couldn't process file #{metadata}. The error was: #{e}."
      raise e
    end
    [csv.first, csv.slice(1, csv.length)]
  end

  # @param [Array] row
  # @return [Array]
  def self.validate_headers(row)
    row.compact!

    # Allow headers with the pattern *_type to specify the record type
    # for a local authority.  e.g. For an author, author_type might be
    # 'Person'.
    difference = (row - valid_headers).reject { |h| h.match(TYPE_HEADER_PATTERN) }

    raise "Invalid headers: #{difference.join(", ")}" unless difference.blank?

    validate_header_pairs(row)
    row
  end

  # If you have a header like lc_subject_type, the next
  # header must be the corresponding field (e.g. lc_subject)
  #
  # @param [Array] row
  def self.validate_header_pairs(row)
    errors = []
    row.each_with_index do |header, i|
      next if header == "work_type"
      next unless header.match(TYPE_HEADER_PATTERN)
      next_header = row[i + 1]
      field_name = header.gsub("_type", "")
      if next_header != field_name
        errors << "Invalid headers: '#{header}' column must be immediately followed by '#{field_name}' column."
      end
    end
    raise errors.join(", ") unless errors.blank?
  end

  # @return [Array]
  def self.valid_headers
    Image.attribute_names + %w(id type note_type note files) +
      time_span_headers + collection_headers
  end

  # @return [Array]
  def self.time_span_headers
    %w(created issued date_copyrighted date_valid).flat_map do |prefix|
      TimeSpan.properties.keys.map { |attribute| "#{prefix}_#{attribute}" }
    end
  end

  # @return [Array]
  def self.collection_headers
    %w(collection_id collection_title collection_accession_number)
  end

  # Maps a row of CSV metadata to the CSV headers
  #
  # @param [Array] headers
  # @param [Array] row
  #
  # @return [Hash]
  def self.csv_attributes(headers, row)
    {}.tap do |processed|
      headers.each_with_index do |header, index|
        extract_field(header, row[index], processed)
      end
    end
  end

  # @param [String] header the column heading
  # @param [String] val the associated value
  # @param [Hash] processed
  def self.extract_field(header, val, processed)
    return unless val
    case header
    when "type", "id"
      # type and id are singular
      processed[header.to_sym] = val
    when /^(created|issued|date_copyrighted|date_valid)_(.*)$/
      key = "#{Regexp.last_match(1)}_attributes".to_sym
      # TODO: this only handles one date of each type
      processed[key] ||= [{}]
      update_date(processed[key].first, Regexp.last_match(2), val)
    when "work_type"
      extract_multi_value_field(header, val, processed)
    when TYPE_HEADER_PATTERN
      update_typed_field(header, val, processed)
    when /^collection_(.*)$/
      processed[:collection] ||= {}
      update_collection(processed[:collection], Regexp.last_match(1), val)
    else
      last_entry = Array(processed[header.to_sym]).last
      if last_entry.is_a?(Hash) && !last_entry[:name]
        update_typed_field(header, val, processed)
      else
        extract_multi_value_field(header, val, processed)
      end
    end
  end

  # Transform coordinates as provided in CSV spreadsheet into dcmi-box formatting
  # Output should look like 'northlimit=43.039; eastlimit=-69.856; southlimit=42.943; westlimit=-71.032; units=degrees; projection=EPSG:4326'
  # TODO: The transform_coordinates_to_dcmi_box method should invoke a DCMIBox.new method
  # DCMI behaviors should be encapsulated there and it should have a .to_s method
  # @param [Hash] attrs A hash of attributes that will become a fedora object
  # @return [Hash]
  def self.transform_coordinates_to_dcmi_box(attrs)
    return attrs unless attrs[:north_bound_latitude] || attrs[:east_bound_longitude] || attrs[:south_bound_latitude] || attrs[:west_bound_longitude]

    if attrs[:north_bound_latitude]
      north = "northlimit=#{attrs.delete(:north_bound_latitude).first}; "
    end
    if attrs[:east_bound_longitude]
      east = "eastlimit=#{attrs.delete(:east_bound_longitude).first}; "
    end
    if attrs[:south_bound_latitude]
      south = "southlimit=#{attrs.delete(:south_bound_latitude).first}; "
    end
    if attrs[:west_bound_longitude]
      west = "westlimit=#{attrs.delete(:west_bound_longitude).first}; "
    end
    attrs[:coverage] = "#{north}#{east}#{south}#{west}units=degrees; projection=EPSG:4326"
    attrs
  end

  # Process the structural metadata, e.g., parent_id, index_map_id
  # TODO: As a first pass, so we can do a complete test of data importing,
  # we're just deleting this data. We need to come back and
  # use it to create links between objects.
  # @param [Hash] attrs A hash of attributes that will become a fedora object
  # @param [Hash]
  def self.handle_structural_metadata(attrs)
    attrs.delete(:parent_title)
    attrs.delete(:parent_id)
    attrs.delete(:parent_accession_number)
    attrs.delete(:index_map_accession_number)
    attrs
  end

  # @param [String] header
  # @param [String] val
  # @param [Hash] processed
  # @param [Symbol] key
  def self.extract_multi_value_field(header, val, processed, key = nil)
    key ||= header.to_sym
    processed[key] ||= []
    val = val.strip
    processed[key] << (looks_like_uri?(val) ? RDF::URI(val) : val)
  end

  # @param [String] str
  def self.looks_like_uri?(str)
    str =~ %r{^https?:\/\/}
  end

  # Fields that have an associated *_type column
  #
  # @param [String] header
  # @param [String] val
  # @param [Hash] processed
  def self.update_typed_field(header, val, processed)
    if header.match(TYPE_HEADER_PATTERN)
      stripped_header = header.gsub("_type", "")
      processed[stripped_header.to_sym] ||= []
      processed[stripped_header.to_sym] << { type: val }
    else
      fields = Array(processed[header.to_sym])
      fields.last[:name] = val
    end
  end

  # @param [Hash] collection
  # @param [String] field
  # @param [String] val
  def self.update_collection(collection, field, val)
    val = [val] unless %w(admin_policy_id id).include? field
    collection[field.to_sym] = val
  end

  def self.update_date(date, field, val)
    date[field.to_sym] ||= []
    date[field.to_sym] << val
  end

  # Given a shorthand string for an access policy,
  # assign the right AccessPolicy object
  # @param [Hash] attrs A hash of attributes that will become a fedora object
  # @return [Hash]
  def self.assign_access_policy(attrs)
    access_policy = if attrs[:access_policy]
                      attrs.delete(:access_policy).first
                    else
                      "public"
                    end
    case access_policy
    when "public"
      attrs[:admin_policy_id] = AdminPolicy::PUBLIC_POLICY_ID
    when "ucsb"
      attrs[:admin_policy_id] = AdminPolicy::UCSB_POLICY_ID
    end
    attrs
  end
end # End of module
