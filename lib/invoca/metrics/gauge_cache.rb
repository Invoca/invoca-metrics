# frozen_string_literal: true

module Invoca
  module Metrics
    class GaugeCache
      GAUGE_REPORT_INTERVAL = 60

      class << self
        def register(client)
          new(client).tap do |gauge_cache|
            Thread.new do
              gauge_cache.report
              sleep(GAUGE_REPORT_INTERVAL)
            end
          end
        end
      end

      attr_reader :cache

      def initialize(client)
        @client = client
        @cache = {}
      end

      # Atomic method for setting the value for a particular gauge
      # When the value is passed as nil, it atomically removes the metric from the cache
      def set(metric, value)
        @cache = @cache.merge(metric => value).compact
      end

      # Reports all gauges that have been set in the cache as directly to the Client's parent method
      # Uses the client that was used to generate the cache
      def report
        @client.batch do |stats_batch|
          statsd_gauge_method_for_batch = ::Statsd.instance_method(:gauge).bind(stats_batch)
          @cache.each { |metric, value| statsd_gauge_method_for_batch.call(metric, value) }
        end
      end
    end
  end
end
