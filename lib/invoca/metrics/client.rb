require 'statsd'

module Invoca
  module Metrics
    class Client < ::Statsd
      STATSD_DEFAULT_HOSTNAME = "127.0.0.1"
      STATSD_DEFAULT_PORT = 8125
      STATSD_METRICS_SEPARATOR = '.'

      MILLISECONDS_IN_SECOND = 1000

      attr_reader :hostname, :port, :statsd_prefix, :server_label, :sub_server_name

      def initialize(hostname, port, cluster_name, service_name, server_label, sub_server_name)

        @hostname        = hostname
        @port            = port
        @cluster_name    = cluster_name
        @service_name    = service_name
        @server_label    = server_label
        @sub_server_name = sub_server_name

        super(@hostname, @port)
        self.namespace = [@cluster_name, @service_name].compact.join(STATSD_METRICS_SEPARATOR).presence
      end

      def server_name # For backwards compatibility
        server_label
      end

      def gauge(name, value)
        if args = metric_args(name, value, "gauge")
          super(*args)
        end
      end

      def count(name, value = 1)
        if args = metric_args(name, value, "counter")
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
        if args = metric_args(name, value, nil)
          super(*args)
        end
      end

      def timer(name, milliseconds = nil, &block)
        name.present? or raise ArgumentError, "Must specify a metric name."
        (!milliseconds.nil? ^ block_given?) or raise ArgumentError, "Must pass exactly one of milliseconds or block."
        name_and_type = [name, "timer", @server_label].join(STATSD_METRICS_SEPARATOR)

        if milliseconds.nil?
          result, block_time = time(name_and_type, &block)
          result
        else
          timing(name_and_type, milliseconds)
        end
      end

      def batch(&block)
        Metrics::Batch.new(self).easy(&block)
      end

      def transmit(message, extra_data={})
        # TODO - we need to wire up exception data to a monitoring service
      end

      def time(stat, sample_rate=1)
        start = Time.now
        result = yield
        length_of_time = ((Time.now - start) * MILLISECONDS_IN_SECOND).round
        timing(stat, length_of_time, sample_rate)
        [result, length_of_time]
      end

      class << self
        # Default values are required for backwards compatibility
        def metrics(statsd_host:     Invoca::Metrics.statsd_host,
                    statsd_port:     Invoca::Metrics.statsd_port,
                    cluster_name:    Invoca::Metrics.cluster_name,
                    service_name:    Invoca::Metrics.service_name,
                    server_name:     Invoca::Metrics.server_name,
                    sub_server_name: Invoca::Metrics.sub_server_name)
          new(statsd_host || Client::STATSD_DEFAULT_HOSTNAME,
              statsd_port || Client::STATSD_DEFAULT_PORT,
              cluster_name,
              service_name,
              server_name,
              sub_server_name)
        end
      end

    protected

      def metric_args(name, value, stat_type)
        name.present? or raise ArgumentError, "Must specify a metric name."
        extended_name = [name, stat_type, @server_label, @sub_server_name].compact.join(STATSD_METRICS_SEPARATOR)
        if value
          [extended_name, value]
        else
          [extended_name]
        end
      end

      def send_to_socket(message)
        self.class.logger.debug { "Statsd: #{message}" } if self.class.logger
        socket.send(message, 0)
      rescue => boom
        self.class.logger.error { "Statsd: #{boom.class} #{boom}" } if self.class.logger
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

