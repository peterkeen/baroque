begin
  require 'mail_client'
rescue LoadError => e
  path = File.expand_path '../../lib', __FILE__
  $:.unshift(path) if File.directory?(path) && !$:.include?(path)
  require 'mail_client'
end

