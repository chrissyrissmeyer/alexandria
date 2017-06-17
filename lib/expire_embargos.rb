# frozen_string_literal: true

module ExpireEmbargos
  def self.run
    assets = EmbargoQueryService.assets_with_expired_embargoes
    assets.each do |asset|
      # If the embargo has lapsed, update the current visibility.
      asset.embargo_visibility!

      # Rather than completly deleting the embargo, we are deactivating it
      # so that the embargo history log can be preserved
      asset.deactivate_embargo!
      asset.save!
    end
    assets.size
  end
end
