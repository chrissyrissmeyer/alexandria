# frozen_string_literal: true

require "rails_helper"

describe CurationConcerns::AccessController do
  let(:mock_etd) { double "The ETD", attributes: [] }
  let(:main_app) { Rails.application.routes.url_helpers }

  before do
    allow(ActiveFedora::Base).to receive(:find).with("123").and_return(mock_etd)
    allow(controller).to receive(:current_user).and_return(user)
  end

  let(:user) { nil }

  describe "#edit" do
    context "when I am not logged in" do
      it "redirects" do
        get :edit, params: { etd_id: "123" }
        expect(response).to redirect_to main_app.new_user_session_path
      end
    end

    context "when I have permission to edit the object" do
      let(:user) { user_with_groups [AdminPolicy::META_ADMIN] }

      context "with an etd" do
        it "shows me the page" do
          expect(controller).to receive(:authorize!).with(:update_rights, mock_etd)
          get :edit, params: { etd_id: "123" }
          expect(assigns[:form]).to be_kind_of EmbargoForm
          expect(response).to be_success
        end
      end

      context "with an image" do
        it "shows me the page" do
          expect(controller).to receive(:authorize!).with(:update_rights, mock_etd)
          get :edit, params: { image_id: "123" }
          expect(assigns[:form]).to be_kind_of EmbargoForm
          expect(response).to be_success
        end
      end
    end
  end

  describe "#update" do
    context "as a metadata admin" do
      let(:user) { user_with_groups [AdminPolicy::META_ADMIN] }

      it "is unauthorized" do
        patch :update, params: { etd_id: "123" }
        expect(response).to redirect_to main_app.root_path
      end
    end

    context "as a rights admin" do
      before do
        AdminPolicy.ensure_admin_policy_exists
      end

      let(:user) { user_with_groups [AdminPolicy::RIGHTS_ADMIN] }

      context "when there is no embargo" do
        it "creates embargo" do
          expect(controller).to receive(:authorize!).with(:update_rights, mock_etd)
          expect(EmbargoService).to receive(:create_or_update_embargo).with(mock_etd,
                                                                            admin_policy_id: "authorities/policies/restricted",
                                                                            embargo_release_date: "2099-07-29T00:00:00+00:00",
                                                                            visibility_after_embargo_id: "authorities/policies/ucsb")
          expect(mock_etd).to receive(:save!)

          patch :update, params: { etd_id: "123", etd: {
            embargo: "true",
            admin_policy_id: "authorities/policies/restricted",
            embargo_release_date: "2099-07-29T00:00:00+00:00",
            visibility_after_embargo_id: "authorities/policies/ucsb",
          }, }
          expect(response).to redirect_to main_app.solr_document_path(mock_etd)
        end
      end

      context "when the etd is already under embargo" do
        it "updates values" do
          expect(controller).to receive(:authorize!).with(:update_rights, mock_etd)
          expect(EmbargoService).to receive(:create_or_update_embargo).with(mock_etd,
                                                                            embargo_release_date: "2099-07-29T00:00:00+00:00",
                                                                            visibility_after_embargo_id: "authorities/policies/ucsb")
          expect(mock_etd).to receive(:save!)

          patch :update, params: { etd_id: "123", etd: {
            embargo: "true",
            embargo_release_date: "2099-07-29T00:00:00+00:00",
            visibility_after_embargo_id: "authorities/policies/ucsb",
          }, }
          expect(response).to redirect_to main_app.solr_document_path(mock_etd)
        end

        it "removes embargo" do
          expect(controller).to receive(:authorize!).with(:update_rights, mock_etd)
          expect(EmbargoService).to receive(:remove_embargo).with(mock_etd)
          expect(mock_etd).to receive(:admin_policy_id=).with("authorities/policies/public")
          expect(mock_etd).to receive(:save!)

          patch :update, params: { etd_id: "123", etd: {
            embargo: "false",
            admin_policy_id: "authorities/policies/public",
            embargo_release_date: "2099-07-29T00:00:00+00:00",
            visibility_after_embargo_id: "authorities/policies/ucsb",
          }, }

          expect(response).to redirect_to main_app.solr_document_path(mock_etd)
        end
      end
    end
  end

  describe "destroy" do
    context "as a rights admin" do
      before do
        AdminPolicy.ensure_admin_policy_exists
        allow(mock_etd).to receive(:embargo).and_return(embargo)
        allow(mock_etd).to receive(:embargo=).with(nil)
        allow(mock_etd).to receive(:embargo_visibility!)
        allow(mock_etd).to receive(:deactivate_embargo!)
        allow(mock_etd).to receive(:save)
        allow(mock_etd).to receive(:save!)

        allow(embargo).to receive(:save!)
      end

      let(:user) { user_with_groups [AdminPolicy::RIGHTS_ADMIN] }
      let(:embargo) { double("the embargo", destroy: true) }

      context "when the etd is already under embargo" do
        it "removes embargo" do
          expect(controller).to receive(:authorize!).with(:update_rights, mock_etd)
          delete :destroy, params: { etd_id: "123" }
          expect(response).to redirect_to main_app.solr_document_path(mock_etd)
        end
      end
    end
  end
end
