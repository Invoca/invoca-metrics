require 'active_support'
require 'active_support/core_ext'

require "invoca/common"

require "invoca/metrics/version"
require "invoca/metrics/client"
require "invoca/metrics/direct_metric"
require "invoca/metrics/batch"

module Invoca
  module Metrics

    class << self
      attr_accessor :service_name, :server_name, :sub_server_name, :cluster_name, :statsd_host, :statsd_port

      def service_name
        if @service_name.nil?
          raise ArgumentError, "You must assign a value to Invoca::Metrics.service_name"
        end
        @service_name
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
