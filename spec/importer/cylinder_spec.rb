require 'rails_helper'
require 'importer'

describe Importer::Cylinder do
  let(:files_dir) { File.join(fixture_path, 'cylinders2') }
  let(:meta_files) {  # Records are spread across 2 files
    [File.join(fixture_path, 'marcxml', 'cylinder_sample_marc.xml'),
     File.join(files_dir, "cylinders_2.xml")]
  }
  let(:options) { {} }
  let(:importer) { described_class.new(meta_files, files_dir, options) }

  before do
    # Don't run background jobs/derivatives during the specs
    allow(CharacterizeJob).to receive_messages(perform_later: nil, perform_now: nil)

    # Don't print output messages during specs
    allow($stdout).to receive(:puts)

    # Don't fetch external records during specs
    allow_any_instance_of(RDF::DeepIndexingService).to receive(:fetch_external)
  end


  # The full import process, from start to finish
  describe 'import records from MARC files' do
    before do
      Organization.destroy_all
      Person.destroy_all
      Group.destroy_all
      FileSet.destroy_all
      AudioRecording.all.map(&:id).each do |id|
        ActiveFedora::Base.find(id).destroy(eradicate: true) if ActiveFedora::Base.exists?(id)
      end
    end

    it 'imports the records' do
      expect {
        VCR.use_cassette('cylinder_import') do
          importer.run
        end
      }
        .to change { AudioRecording.count }.by(3)
        .and(change { FileSet.count }.by(2))

      # Make sure the importer reports the correct number
      expect(importer.imported_records_count).to eq 3

      # The new cylinder records
      record1 = AudioRecording.where(Solrizer.solr_name('system_number', :symbol) => '002556253').first
      record2 = AudioRecording.where(Solrizer.solr_name('system_number', :symbol) => '002145837').first
      record3 = AudioRecording.where(Solrizer.solr_name('system_number', :symbol) => '002145838').first

      # Check the attached files.
      # Both record1 and record3 have cylinder files listed in
      # the MARC file, but there are no files with that name
      # in the files_dir, so no files will get attached for
      # thise spec.
      expect(record1.file_sets).to eq []
      expect(record2.file_sets.map(&:title).flatten).to contain_exactly("Cylinder0006", "Cylinder12783")
      expect(record3.file_sets).to eq []

      # Check the titles
      expect(record1.title).to eq ["Any rags"]
      expect(record2.title).to eq ["In the shade of the old apple tree"]
      expect(record3.title).to eq ["Pagliacci"]

      # Check the metadata for record1
      expect(record1.language.first.rdf_subject).to eq RDF::URI('http://id.loc.gov/vocabulary/iso639-2/eng')
      expect(record1.matrix_number).to eq []

      # Check the contributors are correct
      [:performer, :instrumentalist, :lyricist, :arranger, :singer].each do |property_name|
        contributor = record1.send(property_name)
        expect(contributor.map(&:class).uniq).to eq [Oargun::ControlledVocabularies::Creator]
      end

      # Check local authorities were created for performers
      ids = record1.performer.map { |s| s.rdf_label.first.gsub(%r{^.*\/}, '') }
      perfs = ids.map { |id| ActiveFedora::Base.find(id) }
      org = perfs.find { |target| target.is_a? Organization }
      group = perfs.find { |target| target.is_a? Group }
      person = perfs.find { |target| target.is_a? Person }

      expect(org.foaf_name).to eq 'United States. National Guard Bureau. Fife and Drum Corps.'
      expect(group.foaf_name).to eq 'Allen field c text 1876 field q text'
      expect(person.foaf_name).to eq 'Milner, David,'

      # Check local authorities were created for singers
      ids = record1.singer.map { |s| s.rdf_label.first.gsub(Regexp.new('^.*\/'), '') }
      singers = ids.map { |id| ActiveFedora::Base.find(id) }
      org, person = singers.partition { |obj| obj.is_a?(Organization) }.map(&:first)
      expect(org.foaf_name).to eq 'Louisiana Five. text from b.'
      expect(person.foaf_name).to eq 'Collins, Arthur.'
      expect(person.class).to eq Person

      # This is the same person who is listed as 3 different
      # types of contributor.
      person_id = record1.instrumentalist.first.rdf_label.first.gsub(Regexp.new('^.*\/'), '')
      person = Person.find(person_id)
      expect(person.foaf_name).to eq 'Allen, Thos. S., 1876-1919.'
      [:instrumentalist, :lyricist, :arranger].each do |property_name|
        contributor = record1.send(property_name)
        contributor_id = contributor.first.rdf_label.first.gsub(Regexp.new('^.*\/'), '')
        expect(contributor_id).to eq person.id
      end
    end
  end

  context 'a record without an ARK' do
    let(:files_dir) { File.join(fixture_path, 'marcxml') }
    let(:meta_files) { [File.join(files_dir, "cylinder_missing_ark.xml")] }

    before do
      AudioRecording.all.map(&:id).each do |id|
        ActiveFedora::Base.find(id).destroy(eradicate: true) if ActiveFedora::Base.exists?(id)
      end
    end

    it 'skips that record, but imports other records' do
      expect {
        importer.run
      }.to change { AudioRecording.count }.by(1)
      expect(importer.imported_records_count).to eq 1
    end
  end

  context 'marc file without language' do
    let(:files_dir) { File.join(fixture_path, 'marcxml') }
    let(:meta_files) { [File.join(files_dir, 'cylinder_sample_without_language_marc.xml')] }
    let(:id) { 'f3888888' } # ID from the MARC file

    before do
      ActiveFedora::Base.find(id).destroy(eradicate: true) if ActiveFedora::Base.exists?(id)
    end

    it 'creates the audio record' do
      expect {
        importer.run
      }.to change { AudioRecording.count }.by(1)

      audio = AudioRecording.find(id)
      expect(audio.language).to eq []
    end
  end
end