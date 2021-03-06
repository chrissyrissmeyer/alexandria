# frozen_string_literal: true

require "rails_helper"
require "proquest"

describe Proquest::XML do
  let(:attributes) do
    described_class.attributes(Nokogiri::XML(File.read(file)))
  end

  describe "#attributes" do
    context "a record that has <embargo_code>" do
      let(:file) do
        "#{fixture_path}/proquest/Johnson_ucsb_0035N_12164_DATA.xml"
      end

      it "collects attributes for the ETD record" do
        expect(attributes[:embargo_code]).to eq "3"
        expect(attributes[:DISS_accept_date]).to eq "01/01/2014"
        expect(attributes[:DISS_agreement_decision_date]).to(
          eq "2020-06-11 23:12:18"
        )
        expect(attributes[:DISS_delayed_release]).to eq "2 years"
        expect(attributes[:embargo_remove_date]).to eq nil
        expect(attributes[:DISS_access_option]).to eq "Campus use only"
      end
    end

    context "a record that has <DISS_sales_restriction>" do
      let(:file) { "#{fixture_path}/proquest/Button_ucsb_0035D_11990_DATA.xml" }

      it "collects attributes for the ETD record" do
        expect(attributes[:embargo_code]).to eq "4"
        expect(attributes[:DISS_accept_date]).to eq "01/01/2013"
        expect(attributes[:embargo_remove_date]).to eq "2099-04-24 00:00:00"
      end
    end

    describe "copyright fields" do
      let(:file) { "#{fixture_path}/proquest/Miggs_ucsb_0035D_12446_DATA.xml" }

      it "collects attributes for the ETD record" do
        expect(attributes[:rights_holder]).to eq ["Martin Miggs"]
        expect(attributes[:date_copyrighted]).to eq [2014]
      end
    end
  end # describe #attributes
end
