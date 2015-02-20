require 'rdf/ore'

class Proxy < ActiveFedora::Base
  belongs_to :aggregator, predicate: ::RDF::ORE.proxyIn
  belongs_to :target, predicate: ::RDF::ORE.proxyFor, class_name: 'ActiveFedora::Base'
  belongs_to :next, predicate: ::RDF::IANA.next, class_name: 'Proxy'
  belongs_to :prev, predicate: ::RDF::IANA.prev, class_name: 'Proxy'

  def as_list
    if self.next
      [self] + self.next.as_list
    else
      [self]
    end
  end

end
