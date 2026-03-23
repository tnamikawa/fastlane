module Fastlane
  module Actions
    class UploadIapLocalizationsAction < Action
      def self.run(params)
        require 'spaceship'

        # Login
        api_token = self.api_token(params)
        if api_token
          UI.message("Using App Store Connect API token for authentication")
          Spaceship::ConnectAPI.token = api_token
        elsif params[:username]
          UI.message("Login to App Store Connect (#{params[:username]})")
          Spaceship::ConnectAPI.login(params[:username], use_portal: false, use_tunes: true, tunes_team_id: params[:team_id], team_name: params[:team_name])
          UI.message("Login successful")
        end

        # Get App
        app = Spaceship::ConnectAPI::App.find(params[:app_identifier])
        UI.user_error!("Could not find app with bundle identifier '#{params[:app_identifier]}'") unless app

        # Get all IAPs
        iaps = app.get_in_app_purchases
        UI.message("Found #{iaps.count} in-app purchase(s)")

        # Filter by product_ids if specified
        if params[:product_ids] && !params[:product_ids].empty?
          iaps = iaps.select { |iap| params[:product_ids].include?(iap.product_id) }
          UI.message("Filtered to #{iaps.count} in-app purchase(s)")
        end

        UI.user_error!("No in-app purchases found") if iaps.empty?

        metadata_path = params[:metadata_path]
        UI.user_error!("Metadata directory not found: #{metadata_path}") unless File.directory?(metadata_path)

        updated_count = 0

        iaps.each do |iap|
          iap_dir = File.join(metadata_path, iap.product_id)
          unless File.directory?(iap_dir)
            UI.message("Skipping #{iap.product_id} - no metadata directory found at #{iap_dir}")
            next
          end

          UI.message("Processing IAP: #{iap.product_id}")
          updated_count += upload_localizations_for_iap(iap, iap_dir)
        end

        UI.success("Updated #{updated_count} localization(s)")
      end

      def self.upload_localizations_for_iap(iap, iap_dir)
        existing = iap.get_localizations
        existing_by_locale = existing.each_with_object({}) { |loc, h| h[loc.locale] = loc }

        locale_dirs = Dir.glob(File.join(iap_dir, '*')).select { |d| File.directory?(d) }
        count = 0

        locale_dirs.each do |locale_dir|
          locale = File.basename(locale_dir)
          attributes = {}

          name_file = File.join(locale_dir, "name.txt")
          description_file = File.join(locale_dir, "description.txt")

          attributes["name"] = File.read(name_file).strip if File.exist?(name_file)
          attributes["description"] = File.read(description_file).strip if File.exist?(description_file)

          next if attributes.empty?

          if existing_by_locale[locale]
            UI.message("  Updating localization: #{locale}")
            existing_by_locale[locale].update(attributes: attributes)
          else
            UI.message("  Creating localization: #{locale}")
            attributes["locale"] = locale
            Spaceship::ConnectAPI::InAppPurchaseLocalization.create(
              in_app_purchase_id: iap.id,
              attributes: attributes
            )
          end
          count += 1
        end

        count
      end

      def self.api_token(params)
        api_key = params[:api_key] || Actions.lane_context[SharedValues::APP_STORE_CONNECT_API_KEY]
        return Spaceship::ConnectAPI::Token.create(**api_key) if api_key
        return nil
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Upload In-App Purchase localizations (name and description) to App Store Connect"
      end

      def self.details
        [
          "Upload localized name and description for In-App Purchases.",
          "Metadata is read from the folder structure:",
          "  {metadata_path}/{product_id}/{locale}/name.txt (default: fastlane/metadata_iap/)",
          "  {metadata_path}/{product_id}/{locale}/description.txt"
        ].join("\n")
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :app_identifier,
            env_name: "UPLOAD_IAP_LOCALIZATIONS_APP_IDENTIFIER",
            description: "The bundle identifier of the app",
            type: String,
            default_value: CredentialsManager::AppfileConfig.try_fetch_value(:app_identifier),
            default_value_dynamic: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :metadata_path,
            env_name: "UPLOAD_IAP_LOCALIZATIONS_METADATA_PATH",
            description: "Path to the IAP metadata directory",
            type: String,
            default_value: File.join("fastlane", "metadata_iap")
          ),
          FastlaneCore::ConfigItem.new(
            key: :username,
            env_name: "UPLOAD_IAP_LOCALIZATIONS_USERNAME",
            description: "Your Apple ID username",
            type: String,
            optional: true,
            default_value: CredentialsManager::AppfileConfig.try_fetch_value(:apple_id),
            default_value_dynamic: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :api_key,
            env_name: "UPLOAD_IAP_LOCALIZATIONS_API_KEY",
            description: "App Store Connect API key hash (from app_store_connect_api_key action)",
            type: Hash,
            optional: true,
            sensitive: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :product_ids,
            env_name: "UPLOAD_IAP_LOCALIZATIONS_PRODUCT_IDS",
            description: "Specific IAP product IDs to update (comma-separated). Updates all if not specified",
            type: Array,
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :team_id,
            env_name: "UPLOAD_IAP_LOCALIZATIONS_TEAM_ID",
            description: "The ID of your App Store Connect team",
            type: String,
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :team_name,
            env_name: "UPLOAD_IAP_LOCALIZATIONS_TEAM_NAME",
            description: "The name of your App Store Connect team",
            type: String,
            optional: true
          )
        ]
      end

      def self.authors
        ["fastlane"]
      end

      def self.is_supported?(platform)
        [:ios, :mac].include?(platform)
      end

      def self.category
        :app_store_connect
      end

      def self.example_code
        [
          'upload_iap_localizations(
            app_identifier: "com.example.app",
            metadata_path: "fastlane/metadata/iap"
          )',
          'upload_iap_localizations(
            app_identifier: "com.example.app",
            product_ids: ["com.example.coins_100", "com.example.gems_50"]
          )'
        ]
      end
    end
  end
end
