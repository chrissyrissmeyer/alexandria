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

  def in_collections
    query = ActiveFedora::SolrQueryBuilder.construct_query_for_ids(
      fetch("local_collection_id_ssim", [])
    )
    ActiveFedora::SolrService.query(query, rows: Collection.count)
  end

  def map_sets
    models = fetch("has_model_ssim", [])

    return [self] if models.include? "MapSet"

    query = if models.include? "ComponentMap"
              { id: self["parent_id_ssim"] }
            else
              {
                index_maps_ssim: self["accession_number_ssim"],
                has_model_ssim: "MapSet",
              }
            end
    ActiveFedora::SolrService.query(
      ActiveFedora::SolrQueryBuilder.construct_query(query),
      rows: MapSet.count
    )
  end

  def index_maps
    field_pairs = fetch("index_maps_ssim", []).map do |index|
      ["accession_number_ssim", index]
    end

    query = ActiveFedora::SolrQueryBuilder.construct_query(field_pairs, " OR ")
    ActiveFedora::SolrService.query(query, rows: IndexMap.count)
  end

  def component_maps
    ids = map_sets.map do |set|
      set.fetch("component_maps_ssim", [])
    end

    query = ActiveFedora::SolrQueryBuilder.construct_query_for_ids(ids)
    ActiveFedora::SolrService.query(query, rows: ComponentMap.count)
  end

  private

    def load_file_sets(ids)
      docs = ActiveFedora::SolrService.query("{!terms f=id}#{ids.join(",")}").map { |res| SolrDocument.new(res) }
      ids.map { |id| docs.find { |doc| doc.id == id } }
    end
end
