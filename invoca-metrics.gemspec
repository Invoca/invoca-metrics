# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'invoca/metrics/version'

Gem::Specification.new do |spec|
  spec.name          = "invoca-metrics"
  spec.version       = Invoca::Metrics::VERSION
  spec.authors       = ["Colin Kelley", "Cary Penniman"]
  spec.email         = ["colindkelley@gmail.com", "cpenniman@gmail.com"]
  spec.description   = 'Invoca metrics reporting library'
  spec.summary       = 'Invoca metrics reporting library'
  spec.homepage      = "https://github.com/Invoca/invoca-metrics"
  spec.license       = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").select { |f| f.match(%r{^(lib|README|.*gemspec)}) }
  end

  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport", "~> 4.0"
  spec.add_dependency "rails", "~> 4.0"
  spec.add_dependency "statsd-ruby", "~> 1.2.1"
end
