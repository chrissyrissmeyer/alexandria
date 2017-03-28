# frozen_string_literal: true

# Generated via
#  `rails generate curation_concerns:work ComponentMap`
class ComponentMap < ActiveFedora::Base
  include ::CurationConcerns::WorkBehavior
  include WithAdminPolicy
  include Metadata
  include WithMapSet
  after_save :map_set_update_index

  # Change this to restrict which works can be added as a child.
  # self.valid_child_concerns = []
  validates :title, presence: { message: "Your work must have a title." }

  property :issued, predicate: ::RDF::Vocab::DC.issued, class_name: "TimeSpan"
  property :date_copyrighted, predicate: ::RDF::Vocab::DC.dateCopyrighted, class_name: "TimeSpan"

  accepts_nested_attributes_for :issued, reject_if: :time_span_blank, allow_destroy: true
  accepts_nested_attributes_for :date_copyrighted, reject_if: :time_span_blank, allow_destroy: true

  validates_vocabulary_of :rights_holder
  validates_vocabulary_of :form_of_work

  # must be included after all properties are declared
  include NestedAttributes

  def self.indexer
    ComponentMapIndexer
  end
end
