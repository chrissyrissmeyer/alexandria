# Overrides the CollectionsController provided by hydra-collections
# it provides display and search within collections.
class CollectionsController < ApplicationController
  include CurationConcerns::CollectionsControllerBehavior
  # FIXME: remove once https://github.com/projecthydra/curation_concerns/issues/616 is closed
  include CurationConcerns::ThemedLayoutController

  self.theme = 'alexandria'

  # FIXME: https://github.com/projecthydra/hydra-collections/issues/110
  skip_before_filter :authenticate_user!

  # Overridden to use our local search builders with Admin Policies
  self.list_search_builder_class = ::CollectionsSearchBuilder
  self.single_item_search_builder_class = ::CollectionSearchBuilder
  self.member_search_builder_class = ::CollectionMemberSearchBuilder

  configure_blacklight do |config|
    # Fields for the Collection show page
    config.show_fields.delete(Solrizer.solr_name('description', :stored_searchable))
  end

  def edit
    raise NotImplementedError
  end
end
