module Importer
  module Factory
    module WithAssociatedCollection
      extend ActiveSupport::Concern

      included do
        after_save :reindex_collection
      end

      def create_attributes
        attrs = super.except(:collection)
        attrs.merge!(local_collection_id: [collection.id]) if has_collection?
        attrs
      end

      def update_attributes
        attrs = super.except(:collection)
        attrs.merge!(local_collection_id: [collection.id]) if has_collection?
        attrs
      end

      def reindex_collection
        return unless has_collection?
        collection.update_index
      end


      private

        def has_collection?
          attributes.key?(:collection)
        end

        def collection
          collection_attrs = attributes.fetch(:collection).merge(admin_policy_id: attributes[:admin_policy_id])
          CollectionFactory.new(collection_attrs).find_or_create
        end

    end
  end
end
