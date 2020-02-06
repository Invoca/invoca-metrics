# frozen_string_literal: true

require 'invoca/metrics'
require_relative 'helpers/time_override'
require_relative 'helpers/metrics_test_helpers'

RSpec.configure do |config|
  config.include MetricsTestHelpers
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
end
