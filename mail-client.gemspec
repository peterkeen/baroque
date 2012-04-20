$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "mail-client"
  s.version     = '0.0.1'
  s.date        = `date +%Y-%m-%d`
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Pete Keen"]
  s.email       = ["pete@bugsplat.info"]
  s.summary     = %q{A web-based IMAP client}
  s.description = %q{A web-based IMAP client}

  s.add_dependency('sanitize')
  s.add_dependency("tire")
  s.add_dependency('yajl-ruby')
  s.add_dependency("mail")
  s.add_dependency("rack", ">= 1.3.6")
  s.add_dependency("sinatra")
  s.add_dependency("sinatra-session")
  s.add_dependency("sinatra-contrib")

end
