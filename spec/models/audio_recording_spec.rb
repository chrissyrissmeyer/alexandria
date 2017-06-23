# frozen_string_literal: true

require "rails_helper"

describe AudioRecording do
  describe "::_to_partial_path" do
    subject { described_class._to_partial_path }

    it { is_expected.to eq "catalog/document" }
  end

  describe "#to_solr" do
    let(:audio) { described_class.new }

    it "calls the ImageIndexer" do
      expect_any_instance_of(ObjectIndexer).to(
        receive(:generate_solr_document).and_return({})
      )
      audio.to_solr
    end

    describe "human_readable_type" do
      subject do
        audio.to_solr[Solrizer.solr_name("human_readable_type", :facetable)]
      end

      it { is_expected.to eq "Audio Recording" }
    end

    describe "issue_number" do
      subject { audio.to_solr["issue_number_tesim"] }

      let(:audio) { described_class.new(issue_number: ["12345"]) }

      it { is_expected.to eq ["12345"] }
    end

    describe "matrix_number" do
      subject { audio.to_solr["matrix_number_tesim"] }

      let(:audio) { described_class.new(matrix_number: ["12345"]) }

      it { is_expected.to eq ["12345"] }
    end
  end
end
