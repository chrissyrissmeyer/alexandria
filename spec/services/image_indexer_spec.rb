require 'rails_helper'

describe ImageIndexer do
  subject { ImageIndexer.new(image).generate_solr_document }

  describe 'Indexing dates' do

    context "with an issued date" do
      let(:image) { Image.new(issued_attributes: [{ start: ['1925-11'] }]) }

      it "indexes dates for display" do
        expect(subject['issued_ssm']).to eq "1925-11"
      end

      it "makes a sortable date field" do
        expect(subject['date_si']).to eq '1925-11'
      end

      it "makes a facetable year field" do
        expect(subject['year_iim']).to eq 1925
      end
    end

    context "with issued.start and issued.finish" do
      let(:issued_start) { ['1917'] }
      let(:issued_end) { ['1923'] }
      let(:image) { Image.new(issued_attributes: [{ start: issued_start, finish: issued_end}]) }

      it "indexes dates for display" do
        expect(subject['issued_ssm']).to eq "1917-1923"
      end

      it "makes a sortable date field" do
        expect(subject['date_si']).to eq "1917"
      end

      it "makes a facetable year field" do
        expect(subject['year_iim']).to eq [1917, 1918, 1919, 1920, 1921, 1922, 1923]
      end
    end

    context "with created.start and created.finish" do
      let(:created_start) { ['1917'] }
      let(:created_end) { ['1923'] }
      let(:image) { Image.new(created_attributes: [{ start: created_start, finish: created_end}]) }

      it "indexes dates for display" do
        expect(subject['created_ssm']).to eq "1917-1923"
      end

      it "makes a sortable date field" do
        expect(subject['date_si']).to eq "1917"
      end

      it "makes a facetable year field" do
        expect(subject['year_iim']).to eq [1917, 1918, 1919, 1920, 1921, 1922, 1923]
      end
    end
  end  # Indexing dates


  context 'with local and LOC rights holders' do
    let(:regents_uri) { RDF::URI.new("http://id.loc.gov/authorities/names/n85088322") }
    let(:valerie) { Agent.create(foaf_name: 'Valerie') }
    let(:valerie_uri) { RDF::URI.new(valerie.uri) }

    let(:image) { Image.new(rights_holder: [valerie_uri, regents_uri]) }

    it 'indexes with a label' do
      expect(subject['rights_holder_ssim']).to eq [valerie_uri, regents_uri]
      expect(subject['rights_holder_label_tesim']).to eq ['Valerie', 'University of California (System). Regents']
    end
  end

  context "with rights" do
    let(:pd_uri) { RDF::URI.new('http://creativecommons.org/publicdomain/mark/1.0/') }
    let(:by_uri) { RDF::URI.new('http://creativecommons.org/licenses/by/4.0/') }
    let(:edu_uri) { RDF::URI.new('http://opaquenamespace.org/ns/rights/educational/') }
    let(:image) { Image.new(license: [pd_uri, by_uri, edu_uri]) }

    it 'indexes with a label' do
      expect(subject['license_tesim']).to eq [pd_uri.to_s, by_uri.to_s, edu_uri.to_s]
      expect(subject['license_label_tesim']).to eq ["Public Domain Mark 1.0", "Attribution 4.0 International", "Educational Use Permitted"]
    end
  end

  context "with an ark" do
    let(:image) { Image.new(identifier: ['ark:/99999/fk4123456']) }
    it "indexes ark for display" do
      expect(subject['identifier_ssm']).to eq ['ark:/99999/fk4123456']
    end
  end

  context "with a generic_file" do
    let(:generic_file) { GenericFile.new(id: 'bf/74/27/75/bf742775-2a24-46dc-889e-cca03b27b5f3') }
    let(:image) { Image.new(generic_files: [generic_file]) }

    it "should have a thumbnail image" do
      expect(subject['thumbnail_url_ssm']).to eq ['http://test.host/images/bf%2F74%2F27%2F75%2Fbf742775-2a24-46dc-889e-cca03b27b5f3%2Foriginal/full/300,/0/native.jpg']
    end

    it "should have a medium image" do
      expect(subject['image_url_ssm']).to eq ['http://test.host/images/bf%2F74%2F27%2F75%2Fbf742775-2a24-46dc-889e-cca03b27b5f3%2Foriginal/full/600,/0/native.jpg']
    end

    it "should have a large image" do
      expect(subject['large_image_url_ssm']).to eq ['http://test.host/images/bf%2F74%2F27%2F75%2Fbf742775-2a24-46dc-889e-cca03b27b5f3%2Foriginal/full/1000,/0/native.jpg']
    end
  end

  context "with a title" do
    let(:image) { Image.new(title: 'War and Peace') }

    it 'should have a title' do
      expect(subject['title_tesim']).to eq ['War and Peace']
    end
  end

  context "with subject" do
    let(:lc_subject) { [RDF::URI.new('http://id.loc.gov/authorities/subjects/sh85062487')] }
    let(:image) { Image.new(lc_subject: lc_subject) }

    it "should have a subject" do
      expect(subject['lc_subject_tesim']).to eq ['http://id.loc.gov/authorities/subjects/sh85062487']
      expect(subject['lc_subject_label_tesim']).to eq ['Hotels']
    end
  end

  context "with many types of creator/contributors" do
    let(:creator) { [RDF::URI.new("http://id.loc.gov/authorities/names/n87914041")] }
    let(:singer) { [RDF::URI.new("http://id.loc.gov/authorities/names/n81053687")] }
    let(:person) { Person.create(foaf_name: 'Valerie') }
    let(:photographer) { [RDF::URI.new(person.uri)] }
    let(:image) { Image.new(creator: creator, singer: singer, photographer: photographer) }

    it "should have a creator" do
      expect(subject['creator_tesim']).to eq ['http://id.loc.gov/authorities/names/n87914041']
      expect(subject['creator_label_tesim']).to eq ["American Film Manufacturing Company"]
      expect(subject['creator_label_si']).to eq "American Film Manufacturing Company"
    end

    it "has contributors" do
      expect(subject['contributor_label_tesim']).to eq ["American Film Manufacturing Company", "Valerie", "Haggard, Merle"]
    end
  end

  context "with collections" do
    let(:long_books) { Collection.create!(title: 'Long Books') }
    let(:boring_books) { Collection.create!(title: 'Boring Books') }
    let(:image) { Image.new(collections: [boring_books, long_books]) }

    it 'has collections' do
      expect(subject['collection_ssim']).to eq [boring_books.id, long_books.id]
      expect(subject['collection_label_ssim']).to include 'Long Books', 'Boring Books'
    end
  end

end
