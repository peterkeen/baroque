module Baroque
  class Config
    def initialize
      @vars = {}

      if block_given?
        yield self
      end
    end

    def method_missing(method, *args, &block)
      aname = method.to_s.sub('=','')
      if method.to_s[-1] == '='
        @vars[aname] = args[0]
      else
        return @vars[aname]
      end
    end

  end

  def self.instance
    @@instance ||= Baroque::Config.new do |config|
      config.elasticsearch_url = ENV['ELASTICSEARCH_URL']
      config.object_store_path = "#{ENV['HOME']}/.messages"
    end
  end
end
      
