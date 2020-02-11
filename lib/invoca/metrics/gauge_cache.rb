# frozen_string_literal: true

module Invoca
  module Metrics
    class GaugeCache
      THREAD_CACHE_STORAGE_KEY = "InvocaMetrics_GaugeCache"
      THREAD_REPORT_THREAD_KEY = "InvocaMetrics_GaugeCache_ReportThread"

      class << self
        def [](client)
          Thread.current[THREAD_CACHE_STORAGE_KEY] ||= {}
          Thread.current[THREAD_CACHE_STORAGE_KEY][cache_key_for_client(client)] ||= new(client)
        end

        def start_report_thread(client)
          Thread.current[THREAD_REPORT_THREAD_KEY] ||= {}
          Thread.current[THREAD_REPORT_THREAD_KEY][cache_key_for_client(client)] ||= Thread.new do
            loop do
              GaugeCache[client].report
              sleep 60
            end
          end
        end

        def reset
          Thread.current[THREAD_REPORT_THREAD_KEY] = {}
          Thread.current[THREAD_CACHE_STORAGE_KEY] = {}
        end

        private

        def cache_key_for_client(client)
          [client.hostname, client.port].join("::")
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

      # Reports all gauges that have been set in the cache as counts to the client
      # used to generate the cache
      def report
        @cache.each { |metric, value| @client.count(metric, value) }
      end
    end
  end
end
