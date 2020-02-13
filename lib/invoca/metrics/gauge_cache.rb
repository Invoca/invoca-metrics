# frozen_string_literal: true

module Invoca
  module Metrics
    class GaugeCache
      GAUGE_REPORT_INTERVAL = 60

      class << self
        def register(client)
          registered_gauge_caches[gauge_cache_key_for_client(client)] ||= new(client).tap do |gauge_cache|
            Thread.new do
              gauge_cache.report
              sleep(GAUGE_REPORT_INTERVAL)
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
        @cache = @cache.merge(metric => value)
      end

      # Reports all gauges that have been set in the cache as directly to the Client's parent method
      # Uses the client that was used to generate the cache
      def report
        @client.batch do |stats_batch|
          statsd_gauge_method_for_batch = ::Statsd.instance_method(:gauge).bind(stats_batch)
          @cache.each do |metric, value|
            unless value.nil?
              statsd_gauge_method_for_batch.call(metric, value)
            end
          end
        end
      end
    end
  end
end
