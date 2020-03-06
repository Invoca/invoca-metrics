# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext/module/delegation'

module Invoca
  module Metrics
    class Batch < Client
      delegate :batch_size, :batch_size=, to: :statsd_client

      # @param [Invoca::Metrics::Client] client requires a configured Client instance
      # @param [Statsd::Batch] statsd_batch requires a configured Batch instance
      def initialize(client, statsd_batch)
        super(client.hostname, client.port, client.cluster_name, client.service_name, client.server_label, client.sub_server_name)
        @statsd_client = statsd_batch
      end

      # @yields [Batch] yields itself
      #
      # A convenience method to ensure that data is not lost in the event of an
      # exception being thrown. Batches will be transmitted on the parent socket
      # as soon as the batch is full, and when the block finishes.
      def ensure_send
        yield self
      ensure
        statsd_client.flush
      end
    end
  end
end
