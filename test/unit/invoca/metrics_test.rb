require File.expand_path('../../../test_helper',  __FILE__)

describe Invoca::Metrics do
  include MetricsTestHelpers

  should "raise an exception if service name is not defined" do
    Invoca::Metrics.service_name = nil
    assert_raises(ArgumentError) { Invoca::Metrics.service_name }
  end

  context "ClassMethods" do
    setup do
      stub_metrics(service_name:             "my_service",
                   server_identifier:        :server_name,
                   server_name:              "my_server",
                   statsd_host:              "127.0.0.1",
                   statsd_port:              1,
                   server_group:             "my_group",
                   server_group_statsd_host: "127.0.0.2",
                   server_group_statsd_port: 2,
                   sub_server_name:          "my_sub_server")
    end

    context ".host" do
      should "return statsd_host when server_identifier is :server_name" do
        Invoca::Metrics.server_identifier = :server_name
        assert_equal "127.0.0.1", Invoca::Metrics.host
      end

      should "return server_group_statsd_host when server_identifier is :server_group" do
        Invoca::Metrics.server_identifier = :server_group
        assert_equal "127.0.0.2", Invoca::Metrics.host
      end

      should "return nil when server_identifier doesn't have a match" do
        Invoca::Metrics.server_identifier = :other
        assert_nil Invoca::Metrics.host
      end
    end

    context ".port" do
      should "return statsd_port when server_identifier is :server_name" do
        Invoca::Metrics.server_identifier = :server_name
        assert_equal 1, Invoca::Metrics.port
      end

      should "return server_group_statsd_port when server_identifier is :server_group" do
        Invoca::Metrics.server_identifier = :server_group
        assert_equal 2, Invoca::Metrics.port
      end

      should "return nil when server_identifier doesn't have a match" do
        Invoca::Metrics.server_identifier = :other
        assert_nil Invoca::Metrics.port
      end
    end

    context ".server_label" do
      should "return server_name when server_identifier is :server_name" do
        Invoca::Metrics.server_identifier = :server_name
        assert_equal "my_server", Invoca::Metrics.server_label
      end

      should "return server_group when server_identifier is :server_group" do
        Invoca::Metrics.server_identifier = :server_group
        assert_equal "my_group", Invoca::Metrics.server_label
      end

      should "return nil when server_identifier doesn't have a match" do
        Invoca::Metrics.server_identifier = :other
        assert_nil Invoca::Metrics.server_label
      end
    end
  end
end
