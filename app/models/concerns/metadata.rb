module Metadata
  extend ActiveSupport::Concern
  included do

    # For ARKs
    property :identifier, predicate: ::RDF::DC.identifier

    property :accession_number, predicate: ::RDF::URI('http://opaquenamespace.org/ns/cco/accessionNumber')

    property :title, predicate: ::RDF::DC.title, multiple: false do |index|
      index.as :stored_searchable
    end

    property :alternative, predicate: ::RDF::DC.alternative do |index|
      index.as :stored_searchable
    end

    property :creator, predicate: ::RDF::DC.creator, class_name: Oargun::ControlledVocabularies::Creator do |index|
      index.as :stored_searchable, :facetable
    end

    property :collector, :predicate => Oargun::Vocabularies::MARCREL.col, class_name: Oargun::ControlledVocabularies::Creator do |index|
      index.as :searchable, :displayable
    end

    property :contributor, predicate: ::RDF::DC.contributor do |index|
      index.as :stored_searchable
    end

    property :description, predicate: ::RDF::DC.description do |index|
      index.as :stored_searchable
    end

    property :latitude, predicate: RDF::EXIF.gpsLatitude do |index|
       index.as :displayable
    end

    property :language, predicate: RDF::DC.language,
      class_name: Oargun::ControlledVocabularies::Language do |index|
        index.as :displayable
    end

    property :longitude, predicate: RDF::EXIF.gpsLongitude do |index|
       index.as :displayable
    end

    property :location, predicate: RDF::DC.spatial,
      class_name: Oargun::ControlledVocabularies::Geographic do |index|
        index.as :stored_searchable, :facetable
    end

    property :lc_subject, predicate: RDF::DC.subject, class_name: Oargun::ControlledVocabularies::Subject do |index|
      index.as :stored_searchable, :facetable
    end

    property :publisher, predicate: RDF::DC.publisher do |index|
      index.as :stored_searchable, :facetable
    end

    property :work_type, predicate: RDF::DC.type do |index|
      index.as :stored_searchable
    end

    # Dates
    property :date, predicate: RDF::DC.date do |index|
      index.as :stored_searchable, :facetable
    end
    property :earliestDate, predicate: Oargun::Vocabularies::VRA.earliestDate do |index|
      index.as :stored_searchable, :facetable
    end
    property :issued, predicate: RDF::DC.issued do |index|
      index.as :stored_searchable, :facetable
    end
    property :latestDate, predicate: Oargun::Vocabularies::VRA.latestDate do |index|
      index.as :stored_searchable, :facetable
    end

    # RDA
    property :form_of_work, predicate: RDF::URI('http://www.rdaregistry.info/Elements/w/#formOfWork.en'),
        class_name: Oargun::ControlledVocabularies::WorkType do |index|
      index.as :stored_searchable, :facetable
    end

    property :citation, predicate: RDF::URI('http://www.rdaregistry.info/Elements/u/#preferredCitation.en')

    # MODS
    property :digital_origin, predicate: RDF::Vocab::MODS.digitalOrigin

    property :note, predicate: RDF::Vocab::MODS.note

    property :description_standard, predicate: RDF::Vocab::MODS.recordDescriptionStandard

    property :physical_extent, predicate: RDF::Vocab::MODS.physicalExtent do |index|
      index.as :searchable, :displayable
    end

    property :sub_location, predicate: RDF::Vocab::MODS.locationCopySublocation

    property :record_origin, predicate: RDF::Vocab::MODS.recordOrigin

    # Rights
    property :rights, :predicate => RDF::DC.rights, :class_name => Oargun::ControlledVocabularies::RightsStatement do |index|
      index.as :searchable, :displayable, :facetable
    end

  end

  def controlled_properties
    @controlled_properties ||= self.class.properties.each_with_object([]) do |(key, value), arr|
      if value["class_name"] && (value["class_name"] < ActiveTriples::Resource || value["class_name"].new.resource.class < ActiveTriples::Resource)
        arr << key
      end
    end
  end
end
