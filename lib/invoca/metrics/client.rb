# frozen_string_literal: true

require 'statsd'

module Invoca
  module Metrics
    class Client < ::Statsd
      STATSD_DEFAULT_HOSTNAME = "127.0.0.1"
      STATSD_DEFAULT_PORT = 8125
      STATSD_METRICS_SEPARATOR = '.'

      MILLISECONDS_IN_SECOND = 1000

      attr_reader :hostname, :port, :statsd_prefix, :server_label, :sub_server_name, :gauge_cache

      def initialize(hostname, port, cluster_name, service_name, server_label, sub_server_name)
        @hostname        = hostname
        @port            = port
        @cluster_name    = cluster_name
        @service_name    = service_name
        @server_label    = server_label
        @sub_server_name = sub_server_name

        super(@hostname, @port)
        self.namespace = [@cluster_name, @service_name].compact.join(STATSD_METRICS_SEPARATOR).presence
        @gauge_cache = GaugeCache.register(self)
      end

      def gauge_cache_key
        [
          hostname,
          port,
          namespace,
          server_name,
          sub_server_name
        ].freeze
      end

      def server_name # For backwards compatibility
        server_label
      end

      # This method will store the gauge value passed in so that it is reported every GAUGE_REPORT_INTERVAL
      # seconds and post the gauge at the same time to avoid delay in gauges being
      def gauge_with_caching(name, value)
        if (args = normalized_metric_name_and_value(name, value, "gauge"))
          @gauge_cache.set(*args)
          gauge_without_caching(*args)
        end
      end

      alias gauge_without_caching gauge
      alias gauge gauge_with_caching

      def count(name, value = 1)
        if (args = normalized_metric_name_and_value(name, value, "counter"))
          super(*args)
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
          super(*args)
        end
      end

      def timer(name, milliseconds = nil, return_timing: false, &block)
        name.present? or raise ArgumentError, "Must specify a metric name."
        (!milliseconds.nil? ^ block_given?) or raise ArgumentError, "Must pass exactly one of milliseconds or block."
        name_and_type = [name, "timer", @server_label].join(STATSD_METRICS_SEPARATOR)

        if milliseconds.nil?
          result, block_time = time(name_and_type, &block)
          return_timing ? [result, block_time] : result
        else
          timing(name_and_type, milliseconds)
        end
      end

      def batch(&block)
        Metrics::Batch.new(self).easy(&block)
      end

      def transmit(message, extra_data = {})
        # TODO: - we need to wire up exception data to a monitoring service
      end

      def time(stat, sample_rate = 1)
        start = Time.now
        result = yield
        length_of_time = ((Time.now - start) * MILLISECONDS_IN_SECOND).round
        timing(stat, length_of_time, sample_rate)
        [result, length_of_time]
      end

      class << self
        # Default values are required for backwards compatibility
        def metrics(statsd_host:     Invoca::Metrics.default_client_config[:statsd_host],
                    statsd_port:     Invoca::Metrics.default_client_config[:statsd_port],
                    cluster_name:    Invoca::Metrics.default_client_config[:cluster_name],
                    service_name:    Invoca::Metrics.default_client_config[:service_name],
                    server_name:     Invoca::Metrics.default_client_config[:server_name],
                    sub_server_name: Invoca::Metrics.default_client_config[:sub_server_name])
          effective_statsd_host = statsd_host || Client::STATSD_DEFAULT_HOSTNAME
          effective_statsd_port = statsd_port || Client::STATSD_DEFAULT_PORT

          client_key = [effective_statsd_host, effective_statsd_port, cluster_name, service_name, server_name, sub_server_name].freeze

          client_cache[client_key] ||= new(
            effective_statsd_host,
            effective_statsd_port,
            cluster_name,
            service_name,
            server_name,
            sub_server_name
          )
        end

        def reset_cache
          @client_cache = {}
        end

        private

        def client_cache
          @client_cache ||= {}
        end
      end

      protected

      def normalized_metric_name_and_value(name, value, stat_type)
        name.present? or raise ArgumentError, "Must specify a metric name."
        extended_name = [name, stat_type, @server_label, @sub_server_name].compact.join(STATSD_METRICS_SEPARATOR)
        if value
          [extended_name, value]
        else
          [extended_name]
        end
      end

      def send_to_socket(message)
        # self.class.logger&.debug { "Statsd: #{message}" }
        socket.send(message, 0)
      rescue => ex
        self.class.logger&.error { "Statsd exception sending: #{ex.class}: #{ex}" }
        nil
      end

      private

      def socket
        Thread.current.thread_variable_get(:statsd_socket) || Thread.current.thread_variable_set(:statsd_socket, new_socket)
      end

      def new_socket
        UDPSocket.new.tap { |udp| udp.connect(@host, @port) }
      end
    end
  end
end
