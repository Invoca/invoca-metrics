# Directly reports metrics without sending through statsd.  Does not add process information to metric names.

module Invoca
  module Metrics
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
      SENSU_PORT = 3030
      SENSU_HOST = '127.0.0.1'

      class << self
        def report(metrics)
          timeslot = Time.now.to_i
          metrics_output = [metrics].flatten.map { |m| m.to_s }.join("\n") + "\n"

          send_to_sensu(
              name:         "application_metrics",
              type:         "metric",
              command:      "rr_metrics",
              output:       metrics_output,
              handlers:     ["graphite"],
              issued:       timeslot,
              executed:     timeslot,
              standalone:   true,
              interval:     PERIOD,
              subscribers:  ["all"]
          )
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

        def send_to_sensu(message)
          UDPSocket.new.send(message.to_json + "\n", 0, SENSU_HOST, SENSU_PORT)
        end
      end
    end
  end
end
