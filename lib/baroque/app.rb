require 'rubygems'
require 'sinatra/base'
require 'yajl/json_gem'
require 'baroque/object_store'
require 'baroque/model'
require 'baroque/config'
require 'rubberband'

module Baroque
  class Application < Sinatra::Base

    set :views, [File.join(File.dirname(__FILE__), 'views')]

    helpers do
      def mail_message(msg)
        msg.mail_message(@object_store)
      end

      def mail_text(msg)
        mail = mail_message(msg)
        if mail.multipart?
          mail.text_part.decoded
        else
          mail.decoded
        end
      end
    end

    before do
      @client ||= ElasticSearch.new(
        ENV['ELASTICSEARCH_URL'], 
        :index => 'messages',
        :type => 'message'
      )

      @object_store ||= Baroque::ObjectStore.new(
        ENV['BAROQUE_MESSAGES_PATH']
      )

      @all_labels = Baroque::Message.all_labels(@client).facets['labels']['terms']
    end

    get '/search' do
      query = {
        "sort" => [
          { "date" => { "order" => "desc" } }
        ],
        "query" => {
          "query_string" => { "query" => params['q']}
        }
      }
      @messages = Baroque::Message.search(@client, query)
      erb :messages
    end

    get '/' do
      query = {
        "sort" => [
          { "date" => { "order" => "desc" } }
        ],
        "query" => {
          "query_string" => { "query" => "labels:inbox"}
        }
      }
      @messages = Baroque::Message.search(@client, query)
      erb :messages
    end

    get '/message/:id' do
      @message = Baroque::Message.get(@client, params['id'])
      erb :message
    end

    get '/iframe/:id' do
      @message = Baroque::Message.get(@client, params['id'])
      mail_text(@message)
    end

  end
end
