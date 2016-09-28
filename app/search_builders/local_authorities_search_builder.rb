class LocalAuthoritiesSearchBuilder < Blacklight::SearchBuilder
  include Blacklight::Solr::SearchBuilderBehavior
  include Hydra::PolicyAwareAccessControlsEnforcement

  self.default_processor_chain += [:only_models_for_local_authorities]

  def only_models_for_local_authorities(solr_params)
    solr_params[:fq] ||= []
    solr_params[:fq] << "{!terms f=has_model_ssim}#{LocalAuthority.local_authority_models.join(',')}"
  end
end
