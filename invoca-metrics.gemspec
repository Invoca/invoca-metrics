# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'invoca/metrics/version'

Gem::Specification.new do |spec|
  spec.name          = "invoca-metrics"
  spec.version       = Invoca::Metrics::VERSION
  spec.authors       = ["Invoca development"]
  spec.email         = ["development@invoca.com"]
  spec.description   = 'Invoca metrics reporting library'
  spec.summary       = 'Invoca metrics reporting library'
  spec.homepage      = "https://github.com/Invoca/invoca-metrics"
  spec.license       = "MIT"

  spec.metadata['allowed_push_host'] = "https://rubygems.org"

  spec.files         = [
      *Dir.glob('lib/**/*.rb'),
      'README.md',
      'LICENSE.txt',
      'invoca-metrics.gemspec',
  ]

  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport", "~> 4.0"
  spec.add_dependency "rails", "~> 4.0"
  spec.add_dependency "statsd-ruby", "~> 1.2.1"
end
