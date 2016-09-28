require 'rails_helper'

feature 'Collection:' do
  let!(:collection) { create(:public_collection, description: ['with a description!', '', 'description 3']) }
  let(:user) { create :user }
  let!(:audio1) { create(:public_audio, title: ['Audio 111']) }
  let!(:audio2) { create(:public_audio, title: ['Audio 222']) }

  before do
    login_as user

    # Audio 1 is a member of the collection with the usual
    # hydra style of collection membership.
    collection.members << audio1
    collection.save!

    # Audio 2 is a member of the same collection using
    # the 'Local Membership' work-around.
    audio2.local_collection_id = [collection.id]
    audio2.save!

    # Re-index to get the members
    collection.update_index
  end

  scenario 'viewing the show page for a collection' do
    visit collection_path(collection)

    # It should display both audio records as collection members
    expect(page).to have_link(audio1.title.first)
    expect(page).to have_link(audio2.title.first)
  end
end
