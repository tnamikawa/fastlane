require 'tmpdir'
require 'google/apis/androidpublisher_v3'

describe Fastlane do
  describe Fastlane::FastFile do
    describe "upload_android_iap_localizations" do
      let(:package_name) { "com.fastlane.example" }
      let(:json_key_data) { '{"type":"service_account"}' }
      let(:google_service) { double("google_service") }
      let(:supply_client) { double("supply_client", client: google_service) }
      let(:metadata_path) { @metadata_path }

      around do |example|
        Dir.mktmpdir("android-iap-localizations") do |dir|
          @metadata_path = dir
          example.run
        end
      end

      before do
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

      it "uploads title and description listings for the requested product" do
        write_localization("reward_and", "en-US", "Loot Retrieval", "You can take home the loot.")
        write_localization("reward_and", "ja-JP", "戦利品回収", "戦利品を持ち帰ることができます。")

        existing_listing = AndroidPublisher::InAppProductListing.new(title: "Existing", description: "Existing description")
        product = AndroidPublisher::InAppProduct.new(
          sku: "reward_and",
          listings: {
            "it-IT" => existing_listing
          }
        )

        expect(google_service).to receive(:get_inappproduct).with(package_name, "reward_and").and_return(product)
        expect(google_service).to receive(:patch_inappproduct) do |received_package_name, received_sku, received_product|
          expect(received_package_name).to eq(package_name)
          expect(received_sku).to eq("reward_and")
          expect(received_product.listings["en-US"].title).to eq("Loot Retrieval")
          expect(received_product.listings["en-US"].description).to eq("You can take home the loot.")
          expect(received_product.listings["ja-JP"].title).to eq("戦利品回収")
          expect(received_product.listings["ja-JP"].description).to eq("戦利品を持ち帰ることができます。")
          expect(received_product.listings["it-IT"]).to eq(existing_listing)
        end

        expect(run_action(product_ids: ["reward_and"])).to eq(2)
      end

      it "uploads all product directories when product_ids is omitted" do
        write_localization("coins_100", "en-US", "100 Coins", "Adds 100 coins.")
        write_localization("premium", "en-US", "Premium", "Unlocks premium mode.")

        coins = AndroidPublisher::InAppProduct.new(sku: "coins_100")
        premium = AndroidPublisher::InAppProduct.new(sku: "premium")

        expect(google_service).to receive(:get_inappproduct).with(package_name, "coins_100").and_return(coins)
        expect(google_service).to receive(:patch_inappproduct).with(package_name, "coins_100", coins)
        expect(google_service).to receive(:get_inappproduct).with(package_name, "premium").and_return(premium)
        expect(google_service).to receive(:patch_inappproduct).with(package_name, "premium", premium)

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
        product = AndroidPublisher::InAppProduct.new(sku: "reward_and")

        expect(google_service).to receive(:get_inappproduct).with(package_name, "reward_and").and_return(product)
        expect(google_service).not_to receive(:patch_inappproduct)

        expect do
          run_action(product_ids: ["reward_and"])
        end.to raise_error(FastlaneCore::Interface::FastlaneError, %r{Missing title.txt for reward_and/en-US})
      end
    end
  end
end
