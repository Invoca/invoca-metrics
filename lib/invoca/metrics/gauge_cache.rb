# frozen_string_literal: true

module Invoca
  module Metrics
    class GaugeCache
      GAUGE_REPORT_INTERVAL = 60.seconds

      class << self
        def register(client)
          registered_gauge_caches[client.gauge_cache_key] ||= new(client)
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

      def initialize(client)
        @client = client
        @cache = {}
        start_reporting_thread
      end

      # Atomic method for setting the value for a particular gauge
      def set(metric, value)
        @cache[metric] = value
      end

      # Reports all gauges that have been set in the cache
      def report
        @client.batch do |stats_batch|
          @cache.each do |metric, value|
            stats_batch.gauge_without_caching(metric, value) if value
          end
        end
      end

      private

      def start_reporting_thread
        Thread.new do
          next_time = Time.now.to_f
          loop do
            next_time = ((next_time + GAUGE_REPORT_INTERVAL + 1) / GAUGE_REPORT_INTERVAL * GAUGE_REPORT_INTERVAL) - 1
            report
            sleep([next_time - Time.now.to_f, 0].min)
          end
        end
      end
    end
  end
end
