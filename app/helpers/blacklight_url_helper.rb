module BlacklightUrlHelper
  include Blacklight::UrlHelperBehavior

  def url_for_document doc, options = {}
    return unless doc
    if doc['has_model_ssim'] == ['Collection']
      collections.collection_path(doc.id)
    else
      ark_path(doc.ark.html_safe)
    end
  end

  # we're using our own helper rather than the generated route helper because the
  # default helper escapes slashes. https://github.com/rails/rails/issues/16058
  def ark_path(ark)
    "/lib/#{ark}"
  end

end
