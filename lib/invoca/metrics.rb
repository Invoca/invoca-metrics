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
      attr_accessor :service_name, :server_name, :sub_server_name, :cluster_name, :statsd_host, :statsd_port

      attr_accessor :default_identifier
      attr_writer   :config

      def service_name
        @service_name or raise ArgumentError, "You must assign a value to Invoca::Metrics.service_name"
      end

      def config
        @config ||= {}
      end

      def default_client_config
        {
          service_name:    Invoca::Metrics.service_name,
          server_name:     Invoca::Metrics.server_name,
          cluster_name:    Invoca::Metrics.cluster_name,
          statsd_host:     Invoca::Metrics.statsd_host,
          statsd_port:     Invoca::Metrics.statsd_port,
          sub_server_name: Invoca::Metrics.sub_server_name
        }.merge(config[default_identifier] || {})
      end
    end

    # mix this module into your classes that need to send metrics
    #
    module Source
      extend ActiveSupport::Concern

      module ClassMethods
        def metrics
          @metrics ||= metrics_for(identifier: Invoca::Metrics.default_identifier)
        end

        def metrics_for(identifier:)
          @metrics_for ||= {}
          @metrics_for[identifier] ||=
            begin
              identifier_metrics_config = Invoca::Metrics.config[identifier] || {}
              Client.metrics(Invoca::Metrics.default_client_config.merge(identifier_metrics_config))
            end
        end
      end

      def metrics
        self.class.metrics
      end

      def metrics_for(identifier:)
        self.class.metrics_for(identifier: identifier)
      end
    end
  end
end
