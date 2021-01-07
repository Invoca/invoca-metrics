# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext/module/delegation'

module Invoca
  module Metrics
    class Client
      STATSD_DEFAULT_HOSTNAME = "127.0.0.1"
      STATSD_DEFAULT_PORT = 8125
      STATSD_METRICS_SEPARATOR = '.'

      class << self
        delegate :logger, :logger=, :log_send_failures, :log_send_failures=, to: StatsdClient

        # Default values are required for backwards compatibility
        def metrics(statsd_host:     Invoca::Metrics.default_client_config[:statsd_host],
                    statsd_port:     Invoca::Metrics.default_client_config[:statsd_port],
                    cluster_name:    Invoca::Metrics.default_client_config[:cluster_name],
                    service_name:    Invoca::Metrics.default_client_config[:service_name],
                    server_name:     Invoca::Metrics.default_client_config[:server_name],
                    sub_server_name: Invoca::Metrics.default_client_config[:sub_server_name],
                    namespace:       nil)
          config = {
            hostname:        statsd_host || STATSD_DEFAULT_HOSTNAME,
            port:            statsd_port || STATSD_DEFAULT_PORT,
            cluster_name:    cluster_name,
            service_name:    service_name,
            server_label:    server_name,
            sub_server_name: sub_server_name,
            namespace:       namespace
          }.freeze

          client_cache[config] ||= new(config)
        end

        def reset_cache
          @client_cache = {}
        end

        private

        def client_cache
          @client_cache ||= {}
        end
      end

      attr_reader :hostname, :port, :server_label, :sub_server_name, :cluster_name, :service_name, :gauge_cache
      delegate :batch_size, :namespace, :timing, :time, to: :statsd_client

      def initialize(hostname:, port:, cluster_name: nil, service_name: nil, server_label: nil, sub_server_name: nil, namespace: nil)
        @hostname        = hostname
        @port            = port
        @cluster_name    = cluster_name
        @service_name    = service_name
        @server_label    = server_label
        @sub_server_name = sub_server_name

        @statsd_client = StatsdClient.new(@hostname, @port)
        @statsd_client.namespace = namespace || [@cluster_name, @service_name].compact.join(STATSD_METRICS_SEPARATOR).presence

        @gauge_cache = GaugeCache.register(gauge_cache_key, @statsd_client)
      end

      def gauge_cache_key
        [
          hostname,
          port,
          cluster_name,
          service_name,
          namespace,
          server_name,
          sub_server_name
        ].freeze
      end

      def server_name # For backwards compatibility
        server_label
      end

      # This will store the gauge value passed in so that it is reported every GAUGE_REPORT_INTERVAL
      # seconds and post the gauge at the same time to avoid delay in gauges being
      def gauge(name, value)
        if (args = normalized_metric_name_and_value(name, value, "gauge"))
          gauge_cache.set(*args)
          statsd_client.gauge(*args)
        end
      end

      def count(name, value = 1)
        if (args = normalized_metric_name_and_value(name, value, "counter"))
          statsd_client.count(*args)
        end
      end

      alias counter count

      def increment(name)
        count(name, 1)
      end

      def decrement(name)
        count(name, -1)
      end

      def set(name, value)
        if (args = normalized_metric_name_and_value(name, value, nil))
          statsd_client.set(*args)
        end
      end

      def timer(name, milliseconds = nil, return_timing: false, &block)
        name.present? or raise ArgumentError, "Must specify a metric name."
        (!milliseconds.nil? ^ block_given?) or raise ArgumentError, "Must pass exactly one of milliseconds or block."
        name_and_type = [name, "timer", server_label].join(STATSD_METRICS_SEPARATOR)

        if milliseconds.nil?
          result, block_time = time(name_and_type, &block)
          return_timing ? [result, block_time] : result
        else
          timing(name_and_type, milliseconds)
        end
      end

      def batch(&block)
        statsd_client.batch do |batch|
          Metrics::Batch.new(self, batch).ensure_send(&block)
        end
      end

      # TODO: - implement transmit method
      def transmit(message, extra_data = {})
        # TODO: - we need to wire up exception data to a monitoring service
      end

      private

      attr_reader :statsd_client

      def normalized_metric_name_and_value(name, value, stat_type)
        name.present? or raise ArgumentError, "Must specify a metric name."
        extended_name = [name, stat_type, @server_label, @sub_server_name].compact.join(STATSD_METRICS_SEPARATOR)
        if value
          [extended_name, value]
        else
          [extended_name]
        end
      end
    end
  end
end
