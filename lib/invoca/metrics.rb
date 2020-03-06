# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext'

require "invoca/metrics/version"
require "invoca/metrics/statsd_with_persistent_connection"
require "invoca/metrics/client"
require "invoca/metrics/direct_metric"
require "invoca/metrics/batch"
require "invoca/metrics/gauge_cache"

module Invoca
  module Metrics
    CONFIG_FIELDS = [:service_name, :server_name, :sub_server_name, :cluster_name, :statsd_host, :statsd_port].freeze

    class << self
      attr_accessor(*(CONFIG_FIELDS - [:service_name]), :default_config_key)
      attr_writer :service_name

      def service_name
        @service_name or raise ArgumentError, "You must assign a value to Invoca::Metrics.service_name"
      end

      def initialized?
        @service_name
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
        @metrics_namespace = nil

        def metrics_namespace(namespace)
          @metrics_namespace = namespace
        end

        def metrics
          metrics_for(config_key: Invoca::Metrics.default_config_key)
        end

        def metrics_for(config_key:, namespace: nil)
          metrics_config = Invoca::Metrics.config[config_key] || {}
          namespace_override = { namespace: namespace || @metrics_namespace }.compact
          Client.metrics(Invoca::Metrics.default_client_config.merge(metrics_config).merge(namespace_override))
        end
      end

      def metrics
        self.class.metrics
      end

      def metrics_for(config_key:, namespace: nil)
        self.class.metrics_for(config_key: config_key, namespace: namespace)
      end
    end
  end
end
