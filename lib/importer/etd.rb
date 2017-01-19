require 'proquest'

module Importer
  class ETD

    # Attributes for the ETD collection
    COLLECTION_ATTRIBUTES = { accession_number: ['etds'] }
    attr_reader :collection

    def initialize
      @collection = Importer::Factory::CollectionFactory.new(COLLECTION_ATTRIBUTES).find
    end

    def run
      abort_import unless @collection
    end

    def self.import(meta, data, options)
      ingests = 0

      [Settings.download_root,
       Settings.marc_directory,
       Settings.proquest_directory].each do |dir|
        FileUtils.mkdir_p dir unless Pathname.new(dir).exist?
      end

      if data.empty?
        $stderr.puts 'Nothing found in the data path you specified.'
        return ingests
      end

      importer = new
      importer.run

      raise_error = false

      Dir.mktmpdir do |temp|
        # Don't unzip ETDs we won't use
        etds = data.drop(options[:skip]).map.with_index do |zip, i|
          next unless File.extname(zip) == '.zip'

          # i starts at zero, so use greater-than instead of >=
          if !options[:number] || options[:number] > i
            Proquest.extract(zip, "#{temp}/#{File.basename(zip)}")
          end
        end.compact

        if etds.empty?
          raise ArgumentError, "Number of records skipped (#{options[:skip]}) greater than total records to ingest"
        end

        marc = if meta.empty?
                 puts 'No metadata provided; fetching from Pegasus'
                 etds.map { |e| e[:xml] }.map do |x|
                   if x.nil?
                     $stderr.puts "Bad zipfile source: #{e}"
                     raise IngestError
                   end
                   MARC::XMLReader.new(
                     StringIO.new(
                       Importer::ETDParser.parse_file(x)
                     )
                   ).map { |o| o }
                 end
               else
                 meta.map do |m|
                   # Enumerable methods on XMLReaders are destructive,
                   # so pull the individual records into a regular
                   # Array; see
                   # https://github.com/ruby-marc/ruby-marc/pull/47
                   MARC::XMLReader.new(m).map { |o| o }
                 end
               end.flatten

        marc.each_with_index do |record, count|
          next if options[:number] && options[:number] <= ingests
          next if raise_error

          # The 956$f MARC field holds the name of the PDF from
          # ProQuest; we need this field to match data with metadata
          if record['956'].nil?
            $stderr.puts record
            $stderr.puts
            $stderr.puts 'MARC is missing 956$f field; cannot process this record'
            next
          end

          start_record = Time.now

          indexer = Traject::Indexer.new
          indexer.load_config_file('lib/traject/etd_config.rb')

          proquest_data = etds.select do |etd|
            etd[:pdf].include? record['956']['f']
          end.first
          indexer.settings(etd: proquest_data, local_collection_id: importer.collection.id)

          if options[:verbose]
            puts
            puts "Object attributes for item #{count + 1}:"
            puts record
            puts
            puts "Associated data for item #{count + 1}:"
            puts proquest_data
          end

          begin
            indexer.writer.put indexer.map_record(record)
            indexer.writer.close
            end_record = Time.now
            # Since earlier we skipped the unzip operations we don't
            # need, the array of records to iterate over is smaller, so
            # we modify the numbers here so that we still get the
            # correct "Ingested X of out Y records" readout.
            puts "Ingested record #{count + 1 + options[:skip]} of #{etds.length + options[:skip]} "\
                 "in #{end_record - start_record} seconds"
            ingests += 1
          rescue => e
            $stderr.puts e
            $stderr.puts e.backtrace
            raise_error = true
          rescue Interrupt
            puts "\nIngest stopped, cleaning up..."
            raise_error = true
          end
        end
      end

      if ingests > 0
        puts 'Updating collection index'
        importer.collection.update_index
      end

      raise IngestError.new(reached: ingests - 1) if raise_error
      ingests
    end

    private

      def abort_import
        puts
        puts "ABORTING IMPORT:  Before you can import ETD records, the ETD collection must exist.  Please import the ETD collection record first, then re-try this import."
        puts

        raise CollectionNotFound.new("Not Found: Collection with accession number #{COLLECTION_ATTRIBUTES[:accession_number]}")
      end
  end
end
