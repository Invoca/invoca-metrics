# frozen_string_literal: true

module Invoca
  module Metrics
    class GaugeCache
      GAUGE_REPORT_INTERVAL = 60.seconds

      class << self
        def register(cache_key, statsd_client)
          registered_gauge_caches[cache_key] ||= new(statsd_client)
        end

        def reset
          @registered_gauge_caches = {}
        end

        private

        def registered_gauge_caches
          @registered_gauge_caches ||= {}
        end
      end

      attr_reader :cache

      def initialize(statsd_client)
        @statsd_client = statsd_client
        @cache = {}
        start_reporting_thread
      end

      # Atomic method for setting the value for a particular gauge
      def set(metric, value)
        @cache[metric] = value
      end

      # Reports all gauges that have been set in the cache
      # To avoid "RuntimeError: can't add a new key into hash during iteration" from occurring we are
      # temporarily duplicating the cache to iterate and send the batch of metrics
      def report
        @statsd_client.batch do |statsd_batch|
          @cache.dup.each do |metric, value|
            statsd_batch.gauge(metric, value) if value
          end
        end
      end

      private

      def start_reporting_thread
        Thread.new do
          next_time = Time.now.to_i
          loop do
            next_time = (((next_time + GAUGE_REPORT_INTERVAL + 1) / GAUGE_REPORT_INTERVAL) * GAUGE_REPORT_INTERVAL) - 1
            report
            sleep([next_time - Time.now.to_i, 0].max)
          end
        end
      end
    end
  end
end
