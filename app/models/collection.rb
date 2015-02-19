class Collection < ActiveFedora::Base
  include Hydra::Collection
  include Metadata

  accepts_nested_attributes_for :creator, reject_if: proc { |attributes| attributes[:id].blank? }
  accepts_nested_attributes_for :collector, reject_if: proc { |attributes| attributes[:id].blank? }

  def self.indexer
    CollectionIndexer
  end

end
