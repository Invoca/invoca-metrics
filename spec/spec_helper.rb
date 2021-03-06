# frozen_string_literal: true

require 'invoca/metrics'
require_relative 'helpers/time_override'
require_relative 'helpers/metrics_test_helpers'

RSpec.configure do |config|
  config.include MetricsTestHelpers

  config.after(:each) do
    Invoca::Metrics::Client.reset_cache
    Invoca::Metrics::GaugeCache.reset
  end
end
