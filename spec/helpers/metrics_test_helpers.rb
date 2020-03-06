# frozen_string_literal: true

require_relative 'expose_statsd_client'
require_relative 'track_sent_message'

module MetricsTestHelpers
  include TrackSentMessage

  def stub_metrics_as_production_unicorn
    stub_metrics(server_name: "prod-fe1", cluster_name: nil, service_name: "unicorn")
  end

  def stub_metrics_as_staging_unicorn
    stub_metrics(server_name: "staging-full-fe1", cluster_name: "staging", service_name: "unicorn")
  end

  def stub_metrics(service_name:       nil,
                   server_name:        nil,
                   cluster_name:       nil,
                   statsd_host:        nil,
                   statsd_port:        nil,
                   sub_server_name:    nil,
                   config:             nil,
                   default_config_key: nil)
    Invoca::Metrics.server_name        = server_name
    Invoca::Metrics.cluster_name       = cluster_name
    Invoca::Metrics.service_name       = service_name
    Invoca::Metrics.statsd_host        = statsd_host
    Invoca::Metrics.statsd_port        = statsd_port
    Invoca::Metrics.sub_server_name    = sub_server_name
    Invoca::Metrics.config             = config
    Invoca::Metrics.default_config_key = default_config_key
  end

  def metrics_client_with_message_tracking
    metrics = Invoca::Metrics::Client.metrics
    metrics.extend TrackSentMessage
    metrics
  end

  def mock_timer_and_expected_args(expected_calls)
    any_instance_of(Invoca::Metrics::Client) do |client|
      mock(client).timer.at_least(1).with_any_args do |*args|
        expected_calls.delete(args)
        true
      end
    end
  end

  def mock_gauge_and_expected_args(expected_calls)
    any_instance_of(Invoca::Metrics::Client) do |client|
      mock(client).gauge.at_least(1).with_any_args do |*args|
        expected_calls.delete(args)
        true
      end
    end
  end
end
