describe Spaceship::ConnectAPI::AppInfo do
  include_examples "common spaceship login"

  describe "AppInfo object" do
    describe "#create_app_info_localization" do
      let(:app_info) { Spaceship::ConnectAPI::AppInfo.new('id', {}) }

      it "raises localization errors with the requested locale" do
        expect(Spaceship::ConnectAPI).to receive(:post_app_info_localization)
          .with(app_info_id: 'id', attributes: { locale: 'ja-JP' })
          .and_raise(Spaceship::UnexpectedResponse.new("Cannot add localization due to app name."))

        expect do
          app_info.create_app_info_localization(attributes: { locale: 'ja-JP' })
        end.to raise_error(Spaceship::AppStoreLocalizationError, /locale: ja-JP/)
      end
    end
  end
end
