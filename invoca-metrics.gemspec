# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'invoca/metrics/version'

Gem::Specification.new do |spec|
  spec.name          = "invoca-metrics"
  spec.version       = Invoca::Metrics::VERSION
  spec.authors       = ["Colin Kelley", "Cary Penniman"]
  spec.email         = ["colindkelley@gmail.com","cpenniman@gmail.com"]
  spec.description   = %q{Invoca metrics reporting library}
  spec.summary       = %q{Invoca metrics reporting library}
  spec.homepage      = "https://github.com/Invoca/invoca-metrics"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", "~> 4.0"
  spec.add_dependency "activesupport", "~> 4.0"
  spec.add_dependency "statsd-ruby", "~> 1.2.1"
  spec.add_dependency "keen", "~> 0.9.5"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"

  spec.add_development_dependency "test-unit", "= 1.2.3"
  spec.add_development_dependency "rr", "=1.1.2"
  spec.add_development_dependency "shoulda", "= 3.5.0"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "ruby-prof"
  spec.add_development_dependency "minitest"

end
