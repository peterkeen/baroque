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

    def self.search(client, query, options={})
      options[:fields] = FIELDS.join(",")
      hits = client.search(query, options)
      hits.map { |hit| self.new(hit) }
    end

    def self.all_labels(client)
      query = {
        "facets" => {
          "labels" => {
            "terms" => {
              "field" => "labels",
              "size" => 10000
            }
          }
        },
        "query" => { "match_all" => {} }
      }

      return client.search(query)
    end

    def initialize(hit)
      @hit = hit
    end

    def method_missing(method, *args, &block)
      @hit.fields[method.to_s]
    end

    def mail_message(store)
      raw = store.get_object(key)
      Mail::Message.new(JSON.parse(raw)['original'])
    end

    def id
      @hit.id
    end
  end
end
