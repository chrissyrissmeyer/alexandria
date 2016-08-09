module ApplicationHelper
  include CurationConcerns::CatalogHelper

  def link_to_collection(stuff)
    collection_id = Array(stuff.fetch(:document)[ObjectIndexer::COLLECTION]).first
    if collection_id
      link_to stuff.fetch(:value).first, collections.collection_path(collection_id)
    else
      stuff.fetch(:value).first
    end
  end

  # Used in {CatalogController} to render notes and restrictions as
  # separate paragraphs
  def not_simple_format(data)
    data[:value].map do |val|
      val.split('\n\n').map { |para| "<p>#{para}</p>" }
    end.flatten.join('').html_safe
  end

  def display_link(data)
    href = data.fetch(:value).first
    link_to(href, href)
  end

  def policy_title(document)
    AdminPolicy.find(document.admin_policy_id)
  end
end
