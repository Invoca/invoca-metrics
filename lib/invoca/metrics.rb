require 'active_support'
require 'active_support/core_ext'

require "invoca/common"

require "invoca/metrics/version"
require "invoca/metrics/client"
require "invoca/metrics/direct_metric"
require "invoca/metrics/batch"

module Invoca
  module Metrics
    @server_identifier = :server_name

    class << self
      attr_accessor :service_name, :server_name, :server_group, :sub_server_name, :cluster_name, :server_identifier,
                    :statsd_host, :statsd_port, :server_group_statsd_host, :server_group_statsd_port

      def service_name
        if @service_name.nil?
          raise ArgumentError, "You must assign a value to Invoca::Metrics.service_name"
        end
        @service_name
      end

      def host
        values_by_server_identifier(statsd_host, server_group_statsd_host)[server_identifier]
      end

      def port
        values_by_server_identifier(statsd_port, server_group_statsd_port)[server_identifier]
      end

      def server_label
        values_by_server_identifier(server_name, server_group)[server_identifier]
      end

      private

      def values_by_server_identifier(server_name_value, server_group_value)
        { server_name: server_name_value, server_group: server_group_value }
      end
    end

    # mix this module into your classes that need to send metrics
    #
    module Source
      extend ActiveSupport::Concern

      module ClassMethods
        def metrics
          @metrics ||= Client.metrics
        end
      end

      def metrics
        self.class.metrics
      end
    end

  end
end
