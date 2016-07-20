module Importer
  class Cylinder

    # Array of MARC record files to import.
    attr_reader :metadata_files

    # The directories that contains the binary (audio) files to attach to the cylinder records.
    attr_reader :files_dirs

    # The command line options that were passed in
    attr_reader :options

    # Keep track of how many cylinder records we have imported.
    attr_reader :imported_records_count


    def initialize(metadata_files, files_dirs, options={})
      @metadata_files = metadata_files
      @files_dirs = files_dirs
      @options = options
      @imported_records_count = 0

      $stdout.sync = true  # flush output immediately
    end

    def run
      # XMLReader's Enumerable methods are destructive, so move the
      # MARC::Records to an array so we can measure them:
      # https://github.com/ruby-marc/ruby-marc/pull/47
      marcs = metadata_files.map do |m|
        MARC::XMLReader.new(m).map { |o| o }
      end.flatten

      cylinders = marcs.length

      if options[:skip] && options[:skip] >= cylinders
        raise ArgumentError, "Number of records skipped (#{options[:skip]}) greater than total records to ingest"
      end

      # https://github.com/traject/traject/blob/master/lib/traject/indexer.rb#L101
      indexer = Traject::Indexer.new
      indexer.load_config_file('lib/traject/audio_config.rb')
      print_files_dirs
      indexer.settings(files_dirs: files_dirs)
      indexer.settings(verbose: options[:verbose])

      marcs.each_with_index do |record, count|
        next if options[:skip] && options[:skip] > count
        break if options[:number] && options[:number] <= imported_records_count

        if record['024'].blank? || record['024']['a'].blank?
          puts "Skipping record #{count + 1}: No ARK found"
          next
        end

        print_attributes(record, count + 1)

        start_record = Time.now

        rec = indexer.writer.put indexer.map_record(record)
        @imported_records_count += 1

        end_record = Time.now

        puts "Ingested record #{count + 1} of #{cylinders} "\
          "in #{end_record - start_record} seconds"
      end  # marcs.each_with_index
    ensure
      indexer.writer.close if indexer && indexer.writer
    end


    private

      def print_attributes(record, item_number)
        return unless options[:verbose]
        puts
        puts "Object attributes for item #{item_number}:"
        puts record.class
        puts record
        puts
      end

      def print_files_dirs
        return unless options[:verbose]
        puts
        puts 'Audio files directories:'
        files_dirs.each { |d| puts d }
        puts
      end

  end
end
