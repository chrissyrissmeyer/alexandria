# Agent is a class in FOAF that has possible subclasses of
# Person, Group, or Organization.
# See:  http://xmlns.com/foaf/spec/#term_Agent

class Agent < ActiveFedora::Base

  property :foaf_name, predicate: ::RDF::FOAF.name, multiple: false do |index|
    index.as :stored_searchable, :symbol  # Need :symbol for exact match for ObjectFactory find_or_create_* methods.
  end

  # This allows us to scope queries directly against a specific subclass,
  # Otherwise, "Agent.all" would return instances of any subclass of Agent
  # (e.g. Person)
  def self.exact_model
    where(has_model_ssim: self.to_s)
  end

  def rdf_label
    Array(foaf_name)
  end

end
