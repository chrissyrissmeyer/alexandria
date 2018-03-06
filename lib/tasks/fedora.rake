# frozen_string_literal: true

namespace :fedora do
  desc "Cleans the ActiveFedora repository"
  task clean: [:environment] do
    if Rails.env.production? && !ENV["DO_IT"].to_s.casecmp("true").zero?
      puts "Failsafe: refusing to clean Fedora when RAILS_ENV=production"
      puts
      puts "If you really want to do this, run:"
      puts "  DO_IT=true RAILS_ENV=production rake fedora:clean"
    else
      require "active_fedora/cleaner"
      puts "Cleaning Fedora via 'ActiveFedora.Cleaner.clean!' ..."
      ActiveFedora::Cleaner.clean!
      puts "Finished"
    end
  end

  desc "Print fedora object counts"
  task count: [:environment] do
    puts "Number of objects in fedora:"
    puts "  ActiveFedora::Base: #{ActiveFedora::Base.count}"

    puts "Counts by model:"
    models = [ActiveFedora::Aggregation::ListSource,
              ActiveFedora::Aggregation::Proxy,
              ActiveFedora::IndirectContainer,
              ActiveFedora::DirectContainer,] +
             [Hydra::AdminPolicy,
              Hydra::AccessControl,
              Hydra::AccessControls::Permission,
              Collection,
              FileSet,] +
             CurationConcerns.config.curation_concerns +
             LocalAuthority::LOCAL_AUTHORITY_MODELS - [Agent]

    models.each do |model|
      puts "  #{model}: #{model.count}"
    end
    puts "  Agent: #{Agent.exact_model.count}"
  end
end
