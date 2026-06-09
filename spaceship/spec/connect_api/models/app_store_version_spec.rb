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

      it "raises localization errors with the App Store Connect title and detail" do
        error_body = {
          "errors" => [
            {
              "title" => "The provided entity includes an attribute with an invalid value",
              "detail" => "The app name is already in use.",
              "source" => {
                "pointer" => "/data/attributes/name"
              }
            }
          ]
        }

        expect(Spaceship::ConnectAPI).to receive(:post_app_store_version_localization)
          .with(app_store_version_id: 'id', attributes: { locale: 'ja-JP' })
          .and_raise(Spaceship::UnexpectedResponse.new("Cannot add localization due to app name.", error_body))

        expect do
          app_store_version.create_app_store_version_localization(attributes: { locale: 'ja-JP' })
        end.to raise_error(Spaceship::AppStoreLocalizationError) { |error|
          expect(error.message).to include("Failed to create app store version localization for requested locale: ja-JP")
          expect(error.message).to include("Title: The provided entity includes an attribute with an invalid value")
          expect(error.message).to include("Detail: The app name is already in use.")
          expect(error.message).to include("Source: /data/attributes/name")
          expect(error.message).not_to include("An exception has occurred for locale: ja-JP")
        }
      end
    end
  end
end
