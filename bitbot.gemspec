$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = %q{bitbot}
  s.version     = "0.0.1"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Zach Wily"]
  s.email       = ["zach@zwily.com"]
  s.homepage    = %q{http://github.com/zwily/bitbot}
  s.summary     = %q{Bitcoin IRC Tip Bot}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.default_executable = %q{bitbot}
  s.require_paths = ["lib"]


  s.add_dependency "cinch"
  s.add_dependency "daemons"
  s.add_dependency "sqlite3"
  s.add_dependency "httparty"

  s.add_development_dependency "rspec", "~> 2.5"
  s.add_development_dependency "yard"
end

