# frozen_string_literal: true

module Invoca
  module Metrics
    class GaugeCache
      THREAD_CACHE_STORAGE_KEY = "Invoca::Metric::GaugeCache"
      THREAD_REPORT_THREAD_KEY = "Invoca::Metrics::GaugeCache__ReportThread"
      GAUGE_REPORT_INTERVAL    = 60

      class << self
        def [](client)
          Thread.current[THREAD_CACHE_STORAGE_KEY] ||= {}
          Thread.current[THREAD_CACHE_STORAGE_KEY][cache_key_for_client(client)] ||= new(client)
        end

        def start_report_thread(client)
          Thread.current[THREAD_REPORT_THREAD_KEY] ||= {}
          Thread.current[THREAD_REPORT_THREAD_KEY][cache_key_for_client(client)] ||= Thread.new do
            loop do
              self[client].report
              sleep(GAUGE_REPORT_INTERVAL)
            end
          end
        end

        def reset
          Thread.current[THREAD_REPORT_THREAD_KEY] = {}
          Thread.current[THREAD_CACHE_STORAGE_KEY] = {}
        end

        private

        def cache_key_for_client(client)
          [client.hostname, client.port].freeze
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
