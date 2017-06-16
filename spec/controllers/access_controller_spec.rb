# frozen_string_literal: true

require "rails_helper"

describe AccessController do
  before do
    ETD.where(id: "123").each { |etd| etd.destroy(eradicate: true) }

    AdminPolicy.ensure_admin_policy_exists
    allow(controller).to receive(:current_user).and_return(user)
  end

  let(:user) { nil }

  let!(:etd) do
    create(
      :etd,
      embargo_release_date: Date.parse("2010-10-10"),
      id: "123",
      title: ["mock"],
      visibility_after_embargo: RDF::URI(
        ActiveFedora::Base.id_to_uri(AdminPolicy::PUBLIC_POLICY_ID)
      ),
      visibility_during_embargo: RDF::URI(
        ActiveFedora::Base.id_to_uri(AdminPolicy::UCSB_CAMPUS_POLICY_ID)
      )
    )
  end

  describe "#edit" do
    context "when I'm not logged in" do
      it "redirects me to the login page" do
        get :edit, params: { id: etd.id }
        expect(response).to redirect_to new_user_session_path
      end
    end

    context "when I have permission to edit the object" do
      let(:user) { user_with_groups [AdminPolicy::META_ADMIN] }

      context "with an etd" do
        it "shows me the page" do
          expect(controller).to(
            receive(:authorize!).with(:update_rights, etd)
          )
          get :edit, params: { id: etd.id }
          expect(response).to be_success
        end
      end

      context "with an image" do
        it "shows me the page" do
          expect(controller).to receive(:authorize!).with(:update_rights, etd)
          get :edit, params: { id: etd.id }
          expect(response).to be_success
        end
      end
    end
  end

  describe "#update" do
    context "as a metadata admin" do
      let(:user) { user_with_groups [AdminPolicy::META_ADMIN] }

      it "is unauthorized" do
        post :update, params: { id: etd.id }
        expect(response).to redirect_to root_path
      end
    end

    context "as a rights admin" do
      let(:user) { user_with_groups [AdminPolicy::RIGHTS_ADMIN] }

      context "when there is no embargo" do
        it "creates embargo" do
          post :update,
               params: {
                 admin_policy_id: "authorities/policies/restricted",
                 embargo_release_date: "2099-07-29T00:00:00+00:00",
                 id: etd.id,
                 visibility_after_embargo_id: "authorities/policies/ucsb",
               }

          expect(etd.reload.admin_policy_id).to(
            eq "authorities/policies/restricted"
          )
        end
      end

      context "when the etd is already under embargo" do
        it "updates values" do
          post :update,
               params: {
                 admin_policy_id: "authorities/policies/discovery",
                 id: etd.id,
                 embargo_release_date: "2099-07-29T00:00:00+00:00",
                 visibility_after_embargo_id: "authorities/policies/ucsb",
               }

          expect(etd.reload.admin_policy_id).to(
            eq "authorities/policies/discovery"
          )
        end
      end
    end
  end

  describe "#deactivate" do
    context "when I'm not logged in" do
      it "redirects me to the login page" do
        post :deactivate, params: { id: etd.id }

        expect(response).to redirect_to new_user_session_path
      end
    end

    context "as a rights admin" do
      let(:user) { user_with_groups [AdminPolicy::RIGHTS_ADMIN] }

      it "deactivates the embargo" do
        post :deactivate, params: { id: etd.id }

        expect(etd.reload.admin_policy_id).to eq "authorities/policies/public"
      end
    end
  end

  describe "destroy" do
    context "when I'm not logged in" do
      it "redirects me to the login page" do
        post :destroy, params: { id: etd.id }

        expect(response).to redirect_to new_user_session_path
      end
    end

    context "as a rights admin" do
      let(:user) { user_with_groups [AdminPolicy::RIGHTS_ADMIN] }

      context "when the etd is already under embargo" do
        it "removes embargo" do
          post :destroy, params: { id: etd.id }
          expect(etd.reload.embargo).to be_nil
        end
      end
    end
  end
end
