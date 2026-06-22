require 'credentials_manager/appfile_config'

module Fastlane
  module Actions
    class UploadAndroidIapLocalizationsAction < Action
      def self.run(params)
        require 'supply/client'
        require 'google/apis/androidpublisher_v3'

        metadata_path = params[:metadata_path]
        UI.user_error!("Metadata directory not found: #{metadata_path}") unless File.directory?(metadata_path)

        client = Supply::Client.make_from_config(params: params)
        service = client.client
        package_name = params[:package_name]
        product_ids = products_to_upload(metadata_path: metadata_path, product_ids: params[:product_ids])

        UI.message("Uploading Google Play in-app product localizations for #{product_ids.count} product(s)")

        updated_count = 0
        product_ids.each do |product_id|
          product_dir = File.join(metadata_path, product_id)
          UI.user_error!("Metadata directory not found for product '#{product_id}': #{product_dir}") unless File.directory?(product_dir)

          product = call_google_api do
            service.get_inappproduct(package_name, product_id)
          end

          localizations = localizations_from_directory(product_dir)
          UI.user_error!("No localization metadata found for product '#{product_id}'") if localizations.empty?

          product.listings ||= {}
          localizations.each do |locale, values|
            listing = product.listings[locale] || AndroidPublisher::InAppProductListing.new
            listing.title = values.fetch(:title)
            listing.description = values.fetch(:description)
            product.listings[locale] = listing
          end

          UI.message("Updating product '#{product_id}' with #{localizations.count} localization(s)")
          call_google_api do
            service.patch_inappproduct(package_name, product_id, product)
          end
          updated_count += localizations.count
        end

        UI.success("Updated #{updated_count} Google Play in-app product localization(s)")
        updated_count
      end

      def self.products_to_upload(metadata_path:, product_ids:)
        requested = product_ids ? Array(product_ids).map(&:to_s).reject(&:empty?) : []
        return requested unless requested.empty?

        Dir.glob(File.join(metadata_path, '*')).select { |path| File.directory?(path) }.map { |path| File.basename(path) }.sort
      end

      def self.localizations_from_directory(product_dir)
        locale_dirs = Dir.glob(File.join(product_dir, '*')).select { |path| File.directory?(path) }.sort

        locale_dirs.each_with_object({}) do |locale_dir, result|
          locale = File.basename(locale_dir)
          title_path = File.join(locale_dir, 'title.txt')
          description_path = File.join(locale_dir, 'description.txt')

          validate_text_file!(title_path, product_dir: product_dir, locale: locale, field: 'title')
          validate_text_file!(description_path, product_dir: product_dir, locale: locale, field: 'description')

          result[locale] = {
            title: File.read(title_path, encoding: 'UTF-8').strip,
            description: File.read(description_path, encoding: 'UTF-8').strip
          }
        end
      end

      def self.validate_text_file!(path, product_dir:, locale:, field:)
        UI.user_error!("Missing #{field}.txt for #{File.basename(product_dir)}/#{locale}") unless File.file?(path)
        UI.user_error!("Empty #{field}.txt for #{File.basename(product_dir)}/#{locale}") if File.read(path, encoding: 'UTF-8').strip.empty?
      end

      def self.call_google_api
        yield
      rescue Google::Apis::Error => e
        error = begin
                  JSON.parse(e.body)
                rescue
                  nil
                end
        message = error && error["error"] && error["error"]["message"]
        message ||= e.body
        UI.user_error!("Google Api Error: #{e.message} - #{message}")
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Upload Google Play in-app product localizations"
      end

      def self.details
        [
          "Upload localized title and description for Google Play in-app products.",
          "Metadata is read from:",
          "  {metadata_path}/{product_id}/{locale}/title.txt",
          "  {metadata_path}/{product_id}/{locale}/description.txt"
        ].join("\n")
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :package_name,
                                       env_name: "SUPPLY_PACKAGE_NAME",
                                       description: "The package name of the application to use",
                                       code_gen_sensitive: true,
                                       default_value: CredentialsManager::AppfileConfig.try_fetch_value(:package_name),
                                       default_value_dynamic: true),
          FastlaneCore::ConfigItem.new(key: :metadata_path,
                                       env_name: "UPLOAD_ANDROID_IAP_LOCALIZATIONS_METADATA_PATH",
                                       description: "Path to the Google Play IAP metadata directory",
                                       type: String,
                                       default_value: File.join("fastlane", "metadata_iap_android")),
          FastlaneCore::ConfigItem.new(key: :product_ids,
                                       env_name: "UPLOAD_ANDROID_IAP_LOCALIZATIONS_PRODUCT_IDS",
                                       description: "Specific product IDs to update. Updates all metadata directories if not specified",
                                       type: Array,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :json_key,
                                       env_name: "SUPPLY_JSON_KEY",
                                       short_option: "-j",
                                       conflicting_options: [:json_key_data],
                                       optional: true,
                                       description: "The path to a Google credentials JSON file used to authenticate with Google",
                                       code_gen_sensitive: true,
                                       default_value: CredentialsManager::AppfileConfig.try_fetch_value(:json_key_file),
                                       default_value_dynamic: true,
                                       verify_block: proc do |value|
                                         UI.user_error!("Could not find service account json file at path '#{File.expand_path(value)}'") unless File.exist?(File.expand_path(value))
                                         UI.user_error!("'#{value}' doesn't seem to be a JSON file") unless FastlaneCore::Helper.json_file?(File.expand_path(value))
                                       end),
          FastlaneCore::ConfigItem.new(key: :json_key_data,
                                       env_name: "SUPPLY_JSON_KEY_DATA",
                                       short_option: "-c",
                                       conflicting_options: [:json_key],
                                       optional: true,
                                       description: "The raw content of a Google credentials JSON file used to authenticate with Google",
                                       code_gen_sensitive: true,
                                       default_value: CredentialsManager::AppfileConfig.try_fetch_value(:json_key_data_raw),
                                       default_value_dynamic: true,
                                       verify_block: proc do |value|
                                         begin
                                           JSON.parse(value)
                                         rescue JSON::ParserError
                                           UI.user_error!("Could not parse service account json: JSON::ParseError")
                                         end
                                       end),
          FastlaneCore::ConfigItem.new(key: :root_url,
                                       env_name: "SUPPLY_ROOT_URL",
                                       description: "Root URL for the Google Play API",
                                       optional: true,
                                       verify_block: proc do |value|
                                         UI.user_error!("Could not parse URL '#{value}'") unless value =~ URI.regexp
                                       end),
          FastlaneCore::ConfigItem.new(key: :timeout,
                                       env_name: "SUPPLY_TIMEOUT",
                                       optional: true,
                                       description: "Timeout for read, open, and send (in seconds)",
                                       type: Integer,
                                       default_value: 300)
        ]
      end

      def self.authors
        ["fastlane"]
      end

      def self.is_supported?(platform)
        platform == :android
      end

      def self.category
        :production
      end

      def self.example_code
        [
          'upload_android_iap_localizations(
            package_name: "com.example.app",
            metadata_path: "fastlane/metadata_iap_android"
          )',
          'upload_android_iap_localizations(
            product_ids: ["coins_100", "premium_upgrade"]
          )'
        ]
      end
    end
  end
end
