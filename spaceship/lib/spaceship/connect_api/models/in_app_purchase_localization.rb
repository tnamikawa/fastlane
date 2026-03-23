require_relative '../model'

module Spaceship
  class ConnectAPI
    class InAppPurchaseLocalization
      include Spaceship::ConnectAPI::Model

      attr_accessor :name
      attr_accessor :description
      attr_accessor :locale
      attr_accessor :state

      attr_mapping({
        "name" => "name",
        "description" => "description",
        "locale" => "locale",
        "state" => "state"
      })

      def self.type
        return "inAppPurchaseLocalizations"
      end

      #
      # API
      #

      def self.all(client: nil, in_app_purchase_id:, filter: {}, includes: nil, limit: nil, sort: nil)
        client ||= Spaceship::ConnectAPI
        resps = client.get_in_app_purchase_localizations(in_app_purchase_id: in_app_purchase_id, filter: filter, includes: includes, limit: limit, sort: sort).all_pages
        return resps.flat_map(&:to_models)
      end

      def self.create(client: nil, in_app_purchase_id:, attributes: {})
        client ||= Spaceship::ConnectAPI
        resp = client.post_in_app_purchase_localization(in_app_purchase_id: in_app_purchase_id, attributes: attributes)
        return resp.to_models.first
      end

      def update(client: nil, attributes: {})
        client ||= Spaceship::ConnectAPI
        attributes = reverse_attr_mapping(attributes)
        client.patch_in_app_purchase_localization(in_app_purchase_localization_id: id, attributes: attributes)
      end

      def delete!(client: nil)
        client ||= Spaceship::ConnectAPI
        client.delete_in_app_purchase_localization(in_app_purchase_localization_id: id)
      end
    end
  end
end
