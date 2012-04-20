require 'rubygems'
require 'sinatra/base'
require 'sinatra/session'
require 'mail_client/model'

module MailClient
  class Application < Sinatra::Base
    register Sinatra::Session

    set :session_secret, "blah"
    set :session_expire, 60*60

    before do
      if not session?
        session_start!
      end
    end

    get '/' do
      "hi there"
    end
  end
end
