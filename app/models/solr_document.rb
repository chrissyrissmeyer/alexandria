# -*- encoding : utf-8 -*-
# frozen_string_literal: true

require "local_authority"

class SolrDocument
  include Blacklight::Solr::Document
  include Blacklight::Gallery::OpenseadragonSolrDocument
  include CurationConcerns::SolrDocumentBehavior

  # self.unique_key = 'id'

  # Email uses the semantic field mappings below to generate the body of an email.
  SolrDocument.use_extension(Blacklight::Document::Email)

  # DublinCore uses the semantic field mappings below to assemble an OAI-compliant Dublin Core document
  # Semantic mappings of solr stored fields. Fields may be multi or
  # single valued. See Blacklight::Solr::Document::ExtendableClassMethods#field_semantics
  # and Blacklight::Solr::Document#to_semantic_values
  # Recommendation: Use field names from Dublin Core
  use_extension(Blacklight::Document::DublinCore)

  # Do content negotiation for AF models.
  use_extension(Hydra::ContentNegotiation)

  # This overrides the connection provided by Hydra::ContentNegotiation so we
  # can get the model too.
  module ConnectionWithModel
    def connection
      # TODO: clean the fedora added triples out.
      @connection ||= CleanConnection.new(ActiveFedora.fedora.connection)
    end
  end

  use_extension(ConnectionWithModel)

  # Something besides a local authority
  def curation_concern?
    return false if fetch("has_model_ssim").empty?

    [Collection.to_class_uri, Image.to_class_uri, ETD.to_class_uri].any? do |uri|
      uri == fetch("has_model_ssim").first
    end
  end

  # blank if there is no embargo or the embargo status
  def after_embargo_status
    return if self["visibility_after_embargo_ssim"].blank?

    date = Date.parse self["embargo_release_date_dtsi"]
    policy = AdminPolicy.find(self["visibility_after_embargo_ssim"].first)
    " - Becomes #{policy} on #{date.to_s(:us)}"
  end

  def etd?
    self["has_model_ssim"] == [ETD.to_class_uri]
  end

  def admin_policy_id
    fetch("isGovernedBy_ssim").first
  end

  def to_param
    Identifier.ark_to_noid(ark) || id
  end

  def ark
    Array.wrap(
      self[Solrizer.solr_name("identifier", :displayable)]
    ).first
  end

  # TODO: investigate if this method is still needed.
  def file_sets
    @file_sets ||= begin
      if ids = self[Solrizer.solr_name("member_ids", :symbol)]
        load_file_sets(ids)
      else
        []
      end
    end
  end

  def public_uri
    return nil unless LocalAuthority.local_authority?(self)
    Array.wrap(self["public_uri_ssim"]).first
  end

  def restrictions
    fetch("restrictions_tesim", [])
  end

  def alternative
    fetch("alternative_tesim", [])
  end

  # this overrides CurationConcerns to use the language_label_ssm field
  def language
    fetch("language_label_ssm", [])
  end

  def creator
    fetch("creator_label_tesim", [])
  end

  def issue_number
    fetch("issue_number_ssm", [])
  end

  def matrix_number
    fetch("matrix_number_ssm", [])
  end

  def issued
    fetch(ObjectIndexer::ISSUED, [])
  end

  def place_of_publication
    fetch("place_of_publication_tesim", [])
  end

  def extent
    fetch("extent_ssm", [])
  end

  def scale
    fetch("scale_tesim", [])
  end

  def notes
    fetch("note_label_tesim", [])
  end

  def table_of_contents
    fetch("table_of_contents_tesim", [])
  end

  def form_of_work
    fetch("form_of_work_label_tesim", [])
  end

  def work_type
    fetch("work_type_label_tesim", [])
  end

  def rights_holder
    fetch("rights_holder_label_ssim", [])
  end

  def copyright_status
    fetch("copyright_status_label_tesim", [])
  end

  def sub_location
    fetch("sub_location_ssm", [])
  end

  def accession_number
    fetch("accession_number_tesim", [])
  end

  def location
    fetch("location_label_tesim", [])
  end

  def fulltext_link
    fetch("fulltext_link_ssm", [])
  end

  def citation
    fetch("citation_ssm", [])
  end

  def license
    fetch("license_label_tesim", [])
  end

  def collection
    fetch("collection_label_ssim", [])
  end

  def collection_ids
    fetch("collection_ssim", [])
  end

  private

    def load_file_sets(ids)
      docs = ActiveFedora::SolrService.query("{!terms f=id}#{ids.join(",")}").map { |res| SolrDocument.new(res) }
      ids.map { |id| docs.find { |doc| doc.id == id } }
    end
end
