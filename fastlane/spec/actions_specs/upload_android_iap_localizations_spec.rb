require 'tmpdir'
require 'google/apis/androidpublisher_v3'

describe Fastlane do
  describe Fastlane::FastFile do
    describe "upload_android_iap_localizations" do
      let(:package_name) { "com.fastlane.example" }
      let(:json_key_data) { '{"type":"service_account"}' }
      let(:google_service) { double("google_service") }
      let(:authorization) { double("authorization") }
      let(:supply_client) { double("supply_client", client: google_service) }
      let(:metadata_path) { @metadata_path }

      around do |example|
        Dir.mktmpdir("android-iap-localizations") do |dir|
          @metadata_path = dir
          example.run
        end
      end

      before do
        allow(google_service).to receive(:authorization).and_return(authorization)
        allow(authorization).to receive(:apply!) { |headers| headers["Authorization"] = "Bearer token" }
        allow(Supply::Client).to receive(:make_from_config).and_return(supply_client)
      end

      def write_localization(product_id, locale, title, description)
        locale_dir = File.join(metadata_path, product_id, locale)
        FileUtils.mkdir_p(locale_dir)
        File.write(File.join(locale_dir, "title.txt"), title)
        File.write(File.join(locale_dir, "description.txt"), description)
      end

      def run_action(product_ids: nil)
        product_ids_line = product_ids ? "product_ids: #{product_ids.inspect}," : ""
        Fastlane::FastFile.new.parse("lane :test do
          upload_android_iap_localizations(
            package_name: '#{package_name}',
            json_key_data: '#{json_key_data}',
            metadata_path: '#{metadata_path}',
            #{product_ids_line}
          )
        end").runner.execute(:test)
      end

      it "uploads title and description listings for the requested one-time product" do
        write_localization("reward_and", "en-US", "Loot Retrieval", "You can take home the loot.")
        write_localization("reward_and", "ja-JP", "戦利品回収", "戦利品を持ち帰ることができます。")

        stub_request(:get, "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/#{package_name}/oneTimeProducts/reward_and")
          .to_return(
            status: 200,
            body: {
              packageName: package_name,
              productId: "reward_and",
              regionsVersion: { version: "2025/03" },
              listings: [
                { languageCode: "it-IT", title: "Existing", description: "Existing description" }
              ]
            }.to_json
          )

        stub_request(:patch, "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/#{package_name}/onetimeproducts/reward_and")
          .with(query: { "updateMask" => "listings", "regionsVersion.version" => "2025/03" }) do |request|
            body = JSON.parse(request.body)
            listings = body.fetch("listings").each_with_object({}) { |listing, result| result[listing.fetch("languageCode")] = listing }
            expect(body["packageName"]).to eq(package_name)
            expect(body["productId"]).to eq("reward_and")
            expect(listings["en-US"]["title"]).to eq("Loot Retrieval")
            expect(listings["en-US"]["description"]).to eq("You can take home the loot.")
            expect(listings["ja-JP"]["title"]).to eq("戦利品回収")
            expect(listings["ja-JP"]["description"]).to eq("戦利品を持ち帰ることができます。")
            expect(listings["it-IT"]["title"]).to eq("Existing")
          end.to_return(status: 200, body: {}.to_json)

        expect(google_service).not_to receive(:patch_inappproduct)

        expect(run_action(product_ids: ["reward_and"])).to eq(2)
      end

      it "falls back to legacy in-app products when one-time product lookup returns 404" do
        write_localization("coins_100", "en-US", "100 Coins", "Adds 100 coins.")
        write_localization("premium", "en-US", "Premium", "Unlocks premium mode.")

        coins = AndroidPublisher::InAppProduct.new(sku: "coins_100")
        premium = AndroidPublisher::InAppProduct.new(sku: "premium")

        %w[coins_100 premium].each do |product_id|
          stub_request(:get, "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/#{package_name}/oneTimeProducts/#{product_id}")
            .to_return(status: 404, body: {}.to_json)
        end

        expect(google_service).to receive(:get_inappproduct).with(package_name, "coins_100").and_return(coins)
        expect(google_service).to receive(:patch_inappproduct) do |received_package_name, received_sku, received_product|
          expect(received_package_name).to eq(package_name)
          expect(received_sku).to eq("coins_100")
          expect(received_product.package_name).to eq(package_name)
          expect(received_product.sku).to eq("coins_100")
          expect(received_product.listings["en-US"].title).to eq("100 Coins")
        end
        expect(google_service).to receive(:get_inappproduct).with(package_name, "premium").and_return(premium)
        expect(google_service).to receive(:patch_inappproduct) do |received_package_name, received_sku, received_product|
          expect(received_package_name).to eq(package_name)
          expect(received_sku).to eq("premium")
          expect(received_product.package_name).to eq(package_name)
          expect(received_product.sku).to eq("premium")
          expect(received_product.listings["en-US"].title).to eq("Premium")
        end

        expect(run_action).to eq(2)
      end

      it "raises when a requested product directory is missing" do
        expect(google_service).not_to receive(:get_inappproduct)

        expect do
          run_action(product_ids: ["missing_product"])
        end.to raise_error(FastlaneCore::Interface::FastlaneError, /Metadata directory not found for product 'missing_product'/)
      end

      it "raises when a localization title is missing" do
        locale_dir = File.join(metadata_path, "reward_and", "en-US")
        FileUtils.mkdir_p(locale_dir)
        File.write(File.join(locale_dir, "description.txt"), "You can take home the loot.")

        expect(google_service).not_to receive(:patch_inappproduct)

        expect do
          run_action(product_ids: ["reward_and"])
        end.to raise_error(FastlaneCore::Interface::FastlaneError, %r{Missing title.txt for reward_and/en-US})
      end

      it "raises when a localization title is too long for Google Play" do
        write_localization("reward_and", "en-US", "x" * 56, "You can take home the loot.")

        expect(google_service).not_to receive(:patch_inappproduct)

        expect do
          run_action(product_ids: ["reward_and"])
        end.to raise_error(FastlaneCore::Interface::FastlaneError, %r{title.txt for reward_and/en-US is 56 characters})
      end
    end
  end
end
