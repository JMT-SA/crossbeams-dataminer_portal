# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'crossbeams/dataminer_portal/version'

Gem::Specification.new do |spec|
  spec.name          = "crossbeams-dataminer_portal"
  spec.version       = Crossbeams::DataminerPortal::VERSION
  spec.authors       = ["James Silberbauer"]
  spec.email         = ["jamessil@telkomsa.net"]

  spec.summary       = %q{Test web dataminer app}
  spec.description   = %q{Test web dataminer app}
  spec.homepage      = "https://github.com/JMT-SA."
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "sinatra"
  spec.add_dependency "sinatra-contrib"
  spec.add_dependency "sequel"
  spec.add_dependency "pg"
  spec.add_dependency "crossbeams-dataminer"
  spec.add_dependency "rouge"
  spec.add_dependency 'rack-flash3'

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "pry"
end
