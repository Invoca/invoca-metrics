# frozen_string_literal: true

module Invoca
  module Metrics
    # Directly reports metrics without sending through graphite.  Does not add process information to metric names.
    class DirectMetric
      attr_reader :name, :value, :tick

      def initialize(name,value, tick = nil)
        @name = name
        @value = value
        @tick = tick || self.class.rounded_tick
      end

      def to_s
        "#{name} #{value} #{tick}"
      end

      PERIOD = 60
      DEFAULT_PORT = 2003
      DEFAULT_HOST = '127.0.0.1'

      class << self
        def report(metrics)
          metrics_output = [metrics].flatten.map { |m| m.to_s }.join("\n") + "\n"

          send_to_metric_host(metrics_output)
        end

        def generate_distribution(metric_prefix, metric_values, tick = nil)
          fixed_tick = tick || rounded_tick
          sorted_values = metric_values.sort
          count = sorted_values.count

          if count == 0
            [
              new("#{metric_prefix}.count",    count,                    fixed_tick)
            ]
          else
            [
              new("#{metric_prefix}.count",    count,                    fixed_tick),
              new("#{metric_prefix}.max",      sorted_values[-1],        fixed_tick),
              new("#{metric_prefix}.min",      sorted_values[0],         fixed_tick),
              new("#{metric_prefix}.median",   sorted_values[count*0.5], fixed_tick),
              new("#{metric_prefix}.upper_90", sorted_values[count*0.9], fixed_tick)
            ]
          end
        end

        def rounded_tick
          tick = Time.now.to_i
          tick - (tick % PERIOD)
        end

        private

        def send_to_metric_host(message)
          host = ENV["DIRECT_METRIC_HOST"] || DEFAULT_HOST
          port = (ENV["DIRECT_METRIC_PORT"] || DEFAULT_PORT).to_i

          TCPSocket.open(host, port) do |tcp|
            tcp.send(message, 0)
          end
        end
      end
    end
  end
end
