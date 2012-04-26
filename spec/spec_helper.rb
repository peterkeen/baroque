begin
  require 'baroque'
rescue LoadError => e
  path = File.expand_path '../../lib', __FILE__
  $:.unshift(path) if File.directory?(path) && !$:.include?(path)
  require 'baroque'
end

