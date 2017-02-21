# frozen_string_literal: true
# Generated via
#  `rails generate curation_concerns:work MapSet`
class MapSet < ActiveFedora::Base
  include ::CurationConcerns::WorkBehavior
  include WithAdminPolicy
  include Metadata
  # Change this to restrict which works can be added as a child.
  # self.valid_child_concerns = []
  validates :title, presence: { message: "Your work must have a title." }
end
