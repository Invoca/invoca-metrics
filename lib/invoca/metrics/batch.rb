# frozen_string_literal: true

module Invoca
  module Metrics
    class Batch < Client
      attr_accessor :batch_size

      # @param [Statsd] requires a configured Client instance
      def initialize(client)
        @client          = client
        @server_label    = @client.server_label
        @sub_server_name = @client.sub_server_name
        @batch_size      = @client.batch_size
        @gauge_cache     = @client.gauge_cache
        self.namespace   = @client.namespace
        @backlog         = []
      end

      # @yields [Batch] yields itself
      #
      # A convenience method to ensure that data is not lost in the event of an
      # exception being thrown. Batches will be transmitted on the parent socket
      # as soon as the batch is full, and when the block finishes.
      def easy
        yield self
      ensure
        flush
      end

      def flush
        unless @backlog.empty?
          @client.send_to_socket @backlog.join("\n")
          @backlog = []
        end
      end

      protected

      def send_to_socket(message)
        @backlog << message
        if @backlog.size >= @batch_size
          flush
        end
      end
    end
  end
end
