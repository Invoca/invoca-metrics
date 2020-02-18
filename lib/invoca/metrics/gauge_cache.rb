# frozen_string_literal: true

module Invoca
  module Metrics
    class GaugeCache
      GAUGE_REPORT_INTERVAL = 60.seconds

      class << self
        def register(client)
          registered_gauge_caches[gauge_cache_key_for_client(client)] ||= new(client).tap do |gauge_cache|
            Thread.new do
              next_time = Time.now.to_f
              loop do
                next_time = (next_time + GAUGE_REPORT_INTERVAL) / GAUGE_REPORT_INTERVAL * GAUGE_REPORT_INTERVAL
                gauge_cache.report
                sleep(next_time - Time.now.to_f)
              end
            end
          end
        end

        def reset
          @registered_gauge_caches = {}
        end

        private

        def gauge_cache_key_for_client(client)
          [
            client.hostname,
            client.port,
            client.namespace,
            client.server_name,
            client.sub_server_name
          ].freeze
        end

        def registered_gauge_caches
          @registered_gauge_caches ||= {}
        end
      end

      attr_reader :cache

      def initialize(client)
        @client = client
        @cache = {}
      end

      # Atomic method for setting the value for a particular gauge
      # When the value is passed as nil, it merges the value in, which will then be skipped
      # during reporting of gauge metrics
      def set(metric, value)
        @cache[metric] = value
      end

      # Reports all gauges that have been set in the cache as directly to the Client's parent method
      # Uses the client that was used to generate the cache
      def report
        @client.batch do |stats_batch|
          @cache.each do |metric, value|
            stats_batch.gauge_without_caching(metric, value) if value
          end
        end
      end
    end
  end
end
