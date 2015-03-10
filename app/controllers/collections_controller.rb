class CollectionsController < ApplicationController
  include Blacklight::Catalog
  include Hydra::CollectionsControllerBehavior

  def collections_search_builder_class
    CollectionSearchBuilder
  end

  def collection_member_search_builder_class
    CollectionSearchBuilder
  end

  def collection_member_search_logic
    super + [:add_access_controls_to_solr_params]
  end

  def show
    super
    solr_resp, @document = fetch(@collection.id)
  end

  configure_blacklight do |config|
    # Fields for the Collection show page
    config.show_fields.delete(Solrizer.solr_name('description', :stored_searchable))

    # Fields for the Collection index page
    # (Clear out fields that were added by the CatalogController)
    config.index_fields.clear
  end

protected

  # Override Blacklight method so that you can search and
  # facet within the current collection.
  def search_action_url(options={})
    case action_name
      when 'show'
        collections.collection_path(options.except('only_path'.freeze))
      when 'index'
        collections.collections_path(options)
      else
        super(*args)
    end
  end
end
