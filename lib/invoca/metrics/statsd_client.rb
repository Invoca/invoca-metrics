# frozen_string_literal: true

require 'statsd'

module Invoca
  module Metrics
    class StatsdClient < ::Statsd
      MILLISECONDS_IN_SECOND = 1000

      def time(stat, sample_rate = 1)
        start = Time.now
        result = yield
        length_of_time = ((Time.now - start) * MILLISECONDS_IN_SECOND).round
        timing(stat, length_of_time, sample_rate)
        [result, length_of_time]
      end

      def send_to_socket(message)
        self.class.logger&.debug { "Statsd: #{message}" }
        socket.send(message, 0)
      rescue => ex
        self.class.logger&.error { "Statsd exception sending: #{ex.class}: #{ex}" }
        nil
      end

      private

      # Socket connection should be Thread local and not Fiber local
      # Can't use `Thread.current[:statsd_client] ||=` because that will be fiber-local as well.
      def socket
        Thread.current.thread_variable_get(:statsd_socket) || Thread.current.thread_variable_set(:statsd_socket, new_socket)
      end

      def new_socket
        UDPSocket.new.tap { |udp| udp.connect(@host, @port) }
      end
    end
  end
end
