require 'statsd'

module Invoca
  module Metrics
    class Client < ::Statsd
      STATSD_DEFAULT_HOSTNAME = "127.0.0.1"
      STATSD_DEFAULT_PORT = 8125
      STATSD_METRICS_SEPARATOR = '.'

      MILLISECONDS_IN_SECOND = 1000

      attr_reader :hostname, :port, :statsd_prefix, :server_name, :sub_server_name

      def initialize(hostname, port, cluster_name, service_name, server_name, sub_server_name)

        @hostname = hostname
        @port = port
        @cluster_name = cluster_name
        @service_name = service_name
        @server_name =  server_name
        @sub_server_name = sub_server_name

        super(@hostname, @port)
        self.namespace = [@cluster_name, @service_name].compact.join(STATSD_METRICS_SEPARATOR).nonblank?
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
        name.nonblank? or raise ArgumentError, "Must specify a metric name."
        (!milliseconds.nil? ^ block_given?) or raise ArgumentError, "Must pass exactly one of milliseconds or block."
        name_and_type = [name, "timer", @server_name].join(STATSD_METRICS_SEPARATOR)

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
        name_and_type = [stat, "timer", @server_name].join(STATSD_METRICS_SEPARATOR)
        timing(name_and_type, length_of_time, sample_rate)
        [result, length_of_time]
      end

    protected

      def metric_args(name, value, stat_type)
        name.nonblank? or raise ArgumentError, "Must specify a metric name."
        extended_name = [name, stat_type, @server_name, @sub_server_name].compact.join(STATSD_METRICS_SEPARATOR)
        if value
          [extended_name, value]
        else
          [extended_name]
        end
      end

    public

      class << self
        def metrics
          new(Client::STATSD_DEFAULT_HOSTNAME, Client::STATSD_DEFAULT_PORT, Invoca::Metrics.cluster_name, Invoca::Metrics.service_name, Invoca::Metrics.server_name, Invoca::Metrics.sub_server_name)
        end
      end
    end
  end
end
