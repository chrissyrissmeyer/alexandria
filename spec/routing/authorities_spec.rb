# frozen_string_literal: true

require "rails_helper"

describe "routes for local authorities", type: :routing do
  it "has show routes for all types of local authorities" do
    LocalAuthority::LOCAL_AUTHORITY_MODELS.each do |model|
      expect(
        get: "/authorities/#{model.to_s.downcase.pluralize}/123-456"
      ).to(
        route_to(controller: "local_authorities", action: "show", id: "123-456")
      )
    end
  end
end
