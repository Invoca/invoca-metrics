require File.expand_path('../../../test_helper',  __FILE__)

describe Invoca::Metrics do
  include MetricsTestHelpers

  should "raise an exception if service name is not defined" do
    Invoca::Metrics.service_name = nil
    assert_raises(ArgumentError) { Invoca::Metrics.service_name }
  end

  context ".config" do
    should "return empty hash if not set" do
      Invoca::Metrics.config = nil
      assert_equal({}, Invoca::Metrics.config)
    end

    should "raise an argument error if a config is given with an invalid key" do
      expected_allowed_keys = [:service_name, :server_name, :sub_server_name, :cluster_name, :statsd_host, :statsd_port]
      assert_raises(ArgumentError, /Invalid config.*Allowed fields for config key: #{expected_allowed_keys}/) do
        Invoca::Metrics.config = {
          deployment_group: {
            service_name: "Valid deployment group service name key",
            server_name: "Valid deployment group server name key"
          },
          region: {
            service_name: "Valid region service name key",
            invalid_key: "Invalid region key"
          }
        }
      end
    end
  end

  context ".default_client_config" do
    setup do
      @default_values = {
        service_name:    "dummy_service",
        server_name:     "dummy_name",
        cluster_name:    "dummy_cluster",
        statsd_host:     "127.0.0.1",
        statsd_port:     1,
        sub_server_name: "dummy_sub_server"
      }
    end

    should "return default config values when no default_config_key is set" do
      stub_metrics(@default_values)
      assert_nil Invoca::Metrics.default_config_key
      assert_equal @default_values, Invoca::Metrics.default_client_config
    end

    should "return class default values merged with default_config_key config" do
      stub_metrics(@default_values)
      Invoca::Metrics.config = {
        deployment_group: {
          server_name: "primary",
          statsd_host: "127.0.0.100",
          statsd_port: 80,
        }
      }
      Invoca::Metrics.default_config_key = :deployment_group
      expected_client_config = @default_values.merge(server_name: "primary", statsd_host: "127.0.0.100", statsd_port: 80)
      assert_equal expected_client_config, Invoca::Metrics.default_client_config
    end
  end
end
