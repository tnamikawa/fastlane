describe Spaceship::ConnectAPI::AppStoreVersion do
  include_examples "common spaceship login"

  describe "AppStoreVersion object" do
    describe "reverse maps attributes" do
      let(:app_store_version) { Spaceship::ConnectAPI::AppStoreVersion.new('id', {}) }
      let(:attribute_attributes) do
        {
          contact_first_name: "",
          contact_last_name: "",
          contact_phone: "",
          contact_email: "",
          demo_account_name: "",
          demo_account_password: "",
          demo_account_required: "",
          notes: ""
        }
      end

      it "maps attributes names to API names" do
        resp = double
        allow(resp).to receive(:to_models).and_return([])

        expect(Spaceship::ConnectAPI).to receive(:post_app_store_review_detail).with(app_store_version_id: 'id', attributes: {
          "contactFirstName" => "",
          "contactLastName" => "",
          "contactPhone" => "",
          "contactEmail" => "",
          "demoAccountName" => "",
          "demoAccountPassword" => "",
          "demoAccountRequired" => "",
          "notes" => ""
        }).and_return(resp)

        app_store_version.create_app_store_review_detail(attributes: attribute_attributes)
      end
    end

    describe "#create_app_store_version_localization" do
      let(:app_store_version) { Spaceship::ConnectAPI::AppStoreVersion.new('id', {}) }

      it "raises localization errors with the requested locale" do
        expect(Spaceship::ConnectAPI).to receive(:post_app_store_version_localization)
          .with(app_store_version_id: 'id', attributes: { locale: 'ja-JP' })
          .and_raise(Spaceship::UnexpectedResponse.new("Cannot add localization due to app name."))

        expect do
          app_store_version.create_app_store_version_localization(attributes: { locale: 'ja-JP' })
        end.to raise_error(Spaceship::AppStoreLocalizationError, /locale: ja-JP/)
      end
    end
  end
end
