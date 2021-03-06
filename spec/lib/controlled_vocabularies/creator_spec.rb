# frozen_string_literal: true

require "rails_helper"

describe ControlledVocabularies::Creator do
  before do
    described_class.use_vocabulary(
      :lcnames, class: Vocabularies::LCNAMES
    )
  end

  context "when the name is in the vocabulary" do
    let(:name) { RDF::URI.new("http://id.loc.gov/authorities/names/n79081574") }

    it "creates an object" do
      expect do
        described_class.new(name)
      end.not_to raise_error
    end
  end

  context "when the name is not in the vocabulary" do
    let(:name) { RDF::URI.new("http://foo.bar/authorities/names/n79081574") }
    let(:creator) { described_class.new(name) }

    it "is a problem" do
      expect(creator).not_to be_valid

      expect(creator.errors[:base].first).to(
        start_with "http://foo.bar/authorities/names/n79081574 "\
                   "is not a term in a controlled vocabulary"
      )
    end
  end

  context "when initialized without an argument" do
    subject { described_class.new }

    it { is_expected.to be_a_node }
  end
end
