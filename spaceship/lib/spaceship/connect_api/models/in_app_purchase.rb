require_relative '../model'

module Spaceship
  class ConnectAPI
    class InAppPurchase
      include Spaceship::ConnectAPI::Model

      attr_accessor :name
      attr_accessor :product_id
      attr_accessor :in_app_purchase_type
      attr_accessor :state
      attr_accessor :review_note
      attr_accessor :content_hosting

      module InAppPurchaseType
        CONSUMABLE = "CONSUMABLE"
        NON_CONSUMABLE = "NON_CONSUMABLE"
        NON_RENEWING_SUBSCRIPTION = "NON_RENEWING_SUBSCRIPTION"
      end

      module State
        APPROVED = "APPROVED"
        DEVELOPER_ACTION_NEEDED = "DEVELOPER_ACTION_NEEDED"
        DEVELOPER_REMOVED_FROM_SALE = "DEVELOPER_REMOVED_FROM_SALE"
        IN_REVIEW = "IN_REVIEW"
        MISSING_METADATA = "MISSING_METADATA"
        PENDING_BINARY_APPROVAL = "PENDING_BINARY_APPROVAL"
        PROCESSING_CONTENT = "PROCESSING_CONTENT"
        READY_TO_SUBMIT = "READY_TO_SUBMIT"
        REJECTED = "REJECTED"
        WAITING_FOR_REVIEW = "WAITING_FOR_REVIEW"
        WAITING_FOR_UPLOAD = "WAITING_FOR_UPLOAD"
      end

      attr_mapping({
        "name" => "name",
        "productId" => "product_id",
        "inAppPurchaseType" => "in_app_purchase_type",
        "state" => "state",
        "reviewNote" => "review_note",
        "contentHosting" => "content_hosting"
      })

      def self.type
        return "inAppPurchases"
      end

      #
      # API
      #

      def self.all(client: nil, app_id:, filter: {}, includes: nil, limit: nil, sort: nil)
        client ||= Spaceship::ConnectAPI
        resps = client.get_in_app_purchases(app_id: app_id, filter: filter, includes: includes, limit: limit, sort: sort).all_pages
        return resps.flat_map(&:to_models)
      end

      def self.get(client: nil, in_app_purchase_id:, includes: nil)
        client ||= Spaceship::ConnectAPI
        resp = client.get_in_app_purchase(in_app_purchase_id: in_app_purchase_id, includes: includes)
        return resp.to_models.first
      end

      #
      # Localizations
      #

      def get_localizations(client: nil, filter: {}, includes: nil, limit: nil, sort: nil)
        client ||= Spaceship::ConnectAPI
        resps = client.get_in_app_purchase_localizations(in_app_purchase_id: id, filter: filter, includes: includes, limit: limit, sort: sort).all_pages
        return resps.flat_map(&:to_models)
      end
    end
  end
end
