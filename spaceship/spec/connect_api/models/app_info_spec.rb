describe Spaceship::ConnectAPI::AppInfo do
  include_examples "common spaceship login"

  describe "AppInfo object" do
    describe "#create_app_info_localization" do
      let(:app_info) { Spaceship::ConnectAPI::AppInfo.new('id', {}) }

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

        expect(Spaceship::ConnectAPI).to receive(:post_app_info_localization)
          .with(app_info_id: 'id', attributes: { locale: 'ja-JP' })
          .and_raise(Spaceship::UnexpectedResponse.new("Cannot add localization due to app name.", error_body))

        expect do
          app_info.create_app_info_localization(attributes: { locale: 'ja-JP' })
        end.to raise_error(Spaceship::AppStoreLocalizationError) { |error|
          expect(error.message).to include("Failed to create localization for requested locale: ja-JP")
          expect(error.message).to include("Title: The provided entity includes an attribute with an invalid value")
          expect(error.message).to include("Detail: The app name is already in use.")
          expect(error.message).to include("Source: /data/attributes/name")
          expect(error.message).not_to include("An exception has occurred for locale: ja-JP")
        }
      end
    end
  end
end
