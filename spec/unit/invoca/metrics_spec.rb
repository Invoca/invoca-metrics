# frozen_string_literal: true

require_relative '../../spec_helper'

describe Invoca::Metrics do
  describe ".service_name" do
    it "raise an exception if service name is not defined" do
      Invoca::Metrics.service_name = nil
      expect { Invoca::Metrics.service_name }.to raise_error(ArgumentError)
    end
  end

  describe ".initialized?" do
    after(:each) { Invoca::Metrics.service_name = nil }

    it "be falsey when service name not set" do
      Invoca::Metrics.service_name = nil
      expect(Invoca::Metrics.initialized?).to be_falsey
    end

    it "be truthy when service name set" do
      Invoca::Metrics.service_name = "service"
      expect(Invoca::Metrics.initialized?).to be_truthy
    end
  end

  context ".config" do
    it "return empty hash if not set" do
      Invoca::Metrics.config = nil
      expect(Invoca::Metrics.config).to eq({})
    end

    it "raise an argument error if a config is given with an invalid key" do
      expected_allowed_keys = "[:service_name, :server_name, :sub_server_name, :cluster_name, :statsd_host, :statsd_port]"
      config = {
        deployment_group: {
          service_name: "Valid deployment group service name key",
          server_name: "Valid deployment group server name key"
        },
        region: {
          service_name: "Valid region service name key",
          invalid_key: "Invalid region key"
        }
      }

      expect { Invoca::Metrics.config = config }.to(
        raise_error(ArgumentError, /Invalid config.*Allowed fields for config key: #{Regexp.escape(expected_allowed_keys)}/)
      )
    end
  end

  context ".default_client_config" do
    before(:each) do
      @default_values = {
        service_name: "dummy_service",
        server_name: "dummy_name",
        cluster_name: "dummy_cluster",
        statsd_host: "127.0.0.1",
        statsd_port: 1,
        sub_server_name: "dummy_sub_server"
      }
    end

    it "return default config values when no default_config_key is set" do
      stub_metrics(@default_values)
      expect(Invoca::Metrics.default_config_key).to be_nil
      expect(Invoca::Metrics.default_client_config).to eq(@default_values)
    end

    it "return class default values merged with default_config_key config" do
      stub_metrics(@default_values)
      Invoca::Metrics.config = {
        deployment_group: {
          server_name: "primary",
          statsd_host: "127.0.0.100",
          statsd_port: 80
        }
      }
      Invoca::Metrics.default_config_key = :deployment_group

      expected_client_config = @default_values.merge(
        server_name: "primary",
        statsd_host: "127.0.0.100",
        statsd_port: 80
      )

      expect(Invoca::Metrics.default_client_config).to eq(expected_client_config)
    end
  end
end
