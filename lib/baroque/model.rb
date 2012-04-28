require 'rubberband'
require 'mail'
require 'yajl/json_gem'

module Baroque
  class Message

    FIELDS = %w( subject body_preview labels mime_types in_reply_to references thread_id from to cc date key )

    def self.get(client, id)
      hit = client.get(id, :fields => FIELDS.join(","))
      if hit
        return self.new(hit)
      else
        return nil
      end
    end

    def initialize(hit)
      @hit = hit
    end

    def method_missing(method, *args, &block)
      @hit.attributes[method]
    end

    def mail_message(store)
      raw = store.get_object(key)
      Mail::Message.new(JSON.parse(raw)['original'])
    end
  end
end
