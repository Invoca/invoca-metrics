# frozen_string_literal: true

require 'statsd'

module Invoca
  module Metrics
    class Statsd < ::Statsd
      def send_to_socket(message)
        # self.class.logger&.debug { "Statsd: #{message}" }
        socket.send(message, 0)
      rescue => ex
        self.class.logger&.error { "Statsd exception sending: #{ex.class}: #{ex}" }
        nil
      end

      private

      # Socket connection should be Thread local and not Fiber local
      def socket
        Thread.current.thread_variable_get(:statsd_socket) || Thread.current.thread_variable_set(:statsd_socket, new_socket)
      end

      def new_socket
        UDPSocket.new.tap { |udp| udp.connect(@host, @port) }
      end
    end
  end
end
