require 'tire'

module MailClient
  class Message
    include Tire::Model::Persistence

    index_name 'messages'
    document_type 'message'

    property :headers
    property :delivery_handler
    property :transport_encoding
    property :body
    property :body_raw
    property :separate_parts
    property :text_part
    property :html_part
    property :errors
    property :charset
    property :defaulted_charset
    property :perform_deliveries
    property :raise_delivery_errors
    property :delivery_method
    property :mark_for_delete
    property :raw_source
    property :type
    property :id
  end
end
