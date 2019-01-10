require 'active_support'
require 'active_support/core_ext'

require "invoca/common"

require "invoca/metrics/version"
require "invoca/metrics/client"
require "invoca/metrics/direct_metric"
require "invoca/metrics/batch"

module Invoca
  module Metrics
    CONFIG_FIELDS = [:service_name, :server_name, :sub_server_name, :cluster_name, :statsd_host, :statsd_port].freeze

    class << self
      attr_accessor *CONFIG_FIELDS, :default_config_key

      def service_name
        @service_name or raise ArgumentError, "You must assign a value to Invoca::Metrics.service_name"
      end

      def config
        @config ||= {}
      end

      def config=(config_hash)
        config_valid?(config_hash) or raise ArgumentError, "Invalid config #{config_hash}. Allowed fields for config key: #{CONFIG_FIELDS}."
        @config = config_hash
      end

      def default_client_config
        {
          service_name:    Invoca::Metrics.service_name,
          server_name:     Invoca::Metrics.server_name,
          cluster_name:    Invoca::Metrics.cluster_name,
          statsd_host:     Invoca::Metrics.statsd_host,
          statsd_port:     Invoca::Metrics.statsd_port,
          sub_server_name: Invoca::Metrics.sub_server_name
        }.merge(config[default_config_key] || {})
      end

      private

      def config_valid?(config_hash)
        config_hash.nil? || config_hash.all? { |_config_key, config_key_hash| (config_key_hash.keys - CONFIG_FIELDS).empty?  }
      end
    end

    # mix this module into your classes that need to send metrics
    #
    module Source
      extend ActiveSupport::Concern

      module ClassMethods
        def metrics
          @metrics ||= metrics_for(config_key: Invoca::Metrics.default_config_key)
        end

        def metrics_for(config_key:)
          @metrics_for ||= {}
          @metrics_for[config_key] ||=
            begin
              metrics_config = Invoca::Metrics.config[config_key] || {}
              Client.metrics(Invoca::Metrics.default_client_config.merge(metrics_config))
            end
        end
      end

      def metrics
        self.class.metrics
      end

      def metrics_for(config_key:)
        self.class.metrics_for(config_key: config_key)
      end
    end
  end
end
