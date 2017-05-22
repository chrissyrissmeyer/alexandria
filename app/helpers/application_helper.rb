# coding: utf-8
# frozen_string_literal: true

module ApplicationHelper
  include CurationConcerns::CatalogHelper

  # @param [String] string
  # @return [String]
  def linkify(string)
    string.gsub(URI.regexp(%w[http https]),
                '<a href="\1://\4">\1://\4</a>')
  end

  # Used in {CatalogController} to render notes and restrictions as
  # separate paragraphs
  def not_simple_format(data)
    safe_join(
      data[:value].map do |val|
        val.split('\n\n').map { |para| content_tag(:p, para) }
      end.flatten
    )
  end

  def display_link(data)
    href = data.fetch(:value).first
    link_to(href, href)
  end

  def policy_title(document)
    AdminPolicy.find(document.admin_policy_id)
  end

  def random_thumbnail_from_collection(member_docs = [])
    thumb = member_docs.select { |doc| doc.key?("thumbnail_url_ssm") }.sample
    return nil unless thumb
    thumb["thumbnail_url_ssm"]
  end

  def icon_class(file)
    if file.audio?
      "fa-music"
    elsif file.pdf?
      "fa-file-text-o"
    end
  end

  def link_to_file(file)
    if file.pdf?
      link_to(file.fetch("original_filename_ss"),
              Rails.application.routes.url_helpers.download_url(
                file.id,
                only_path: true
              ),
              target: "_blank",
              data: { no_turbolink: true })
    else
      link_to(file.fetch("title_tesim").first,
              main_app.curation_concerns_file_set_path(file))
    end
  end

  def show_license_icons(data)
    uri = data[:document]["license_tesim"].first

    icons = rights_icons(uri).map do |statement|
      image_tag(statement, class: "icon")
    end

    link_to safe_join(icons << " #{data[:value].first}"),
            uri,
            title: "Rights Statement"
  end

  def rights_icons(uri)
    if category = uri.match(%r{.*rightsstatements\.org\/vocab\/([a-z]+)}i)
      [
        case category[1]
        when "InC"
          "rights-statements/InC.Icon-Only.dark.png"
        when "NoC"
          "rights-statements/NoC.Icon-Only.dark.png"
        else
          "rights-statements/Other.Icon-Only.dark.png"
        end,
      ].compact

    elsif categories = uri.match(%r{.*creativecommons\.org\/(licenses|publicdomain)\/([a-z-]+)}i)

      categories[2].split("-").map do |cat|
        "creative-commons/#{cat}.png"
      end
    else
      []
    end
  end

  def embargo_manager?
    can?(:discover, Hydra::AccessControls::Embargo)
  end

  def can_read_authorities?
    can?(:read, :local_authorities)
  end

  def can_destroy_authorities?
    can?(:destroy, :local_authorities)
  end
end
