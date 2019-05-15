# frozen_string_literal: true

require_relative '../../../test_helper'
require_relative '../../../helpers/metrics/metrics_test_helpers'

describe Invoca::Metrics::Client do

  include MetricsTestHelpers
  include ::Rails::Dom::Testing::Assertions::SelectorAssertions

  context "initialization" do
    setup do
      stub_metrics_as_production_unicorn
    end

    should "properly construct with params and statsd both turned on" do
      custom_host = "127.0.0.2"
      custom_port = 8300
      cluster_name = "test_cluster"
      service_name = "test_service"
      server_name = "test_server"
      sub_server_name = "test_sub_server"
      metrics_client = Invoca::Metrics::Client.new(custom_host, custom_port, cluster_name, service_name, server_name, sub_server_name)
      assert_equal custom_host, metrics_client.hostname
      assert_equal custom_port, metrics_client.port
      assert_equal "test_cluster.test_service", metrics_client.namespace
    end

    should "properly construct with defaults such that statsd are enabled" do
      metrics_client = Invoca::Metrics::Client.metrics
      assert_equal Invoca::Metrics::Client::STATSD_DEFAULT_HOSTNAME, metrics_client.hostname
      assert_equal Invoca::Metrics::Client::STATSD_DEFAULT_PORT, metrics_client.port
      assert_equal "unicorn", metrics_client.namespace
    end

    should "properly construct with configured statsd connection information" do
      Invoca::Metrics.statsd_host = "127.0.0.10"
      Invoca::Metrics.statsd_port = 1234
      metrics_client = Invoca::Metrics::Client.metrics
      assert_equal "127.0.0.10", metrics_client.hostname
      assert_equal 1234,         metrics_client.port
    end

    should "properly construct with configured statsd config for default_config_key" do
      stub_metrics(server_name:        "prod-fe1",
                   service_name:       "unicorn",
                   statsd_host:        "127.0.0.1",
                   statsd_port:        443,
                   sub_server_name:    "sub_server_1",
                   config:             { deploy_group: { server_name: "primary", statsd_host: "128.0.0.2", statsd_port: 3001 } },
                   default_config_key: :deploy_group)

      metrics_client = Invoca::Metrics::Client.metrics

      assert_equal "128.0.0.2",    metrics_client.hostname
      assert_equal 3001,           metrics_client.port
      assert_equal "primary",      metrics_client.server_label
      assert_equal "sub_server_1", metrics_client.sub_server_name
    end

    should "construct with given args along with default args" do
      Invoca::Metrics.statsd_host = "127.0.0.10"
      Invoca::Metrics.statsd_port = 1234
      metrics_client = Invoca::Metrics::Client.metrics(statsd_host: "127.0.0.255", statsd_port: 5678)
      assert_equal "127.0.0.255", metrics_client.hostname
      assert_equal 5678,          metrics_client.port
    end
  end

  context "#server_name" do
    should "return server_label for backwards compatibility" do
      stub_metrics_as_production_unicorn
      metrics_client = Invoca::Metrics::Client.metrics
      assert_equal metrics_client.server_name, metrics_client.server_label
      assert_equal "prod-fe1", metrics_client.server_name
    end
  end

  context "reporting to statsd" do

    context "in the production environment" do
      setup do
        stub_metrics_as_production_unicorn
        @metrics_client = metrics_client_with_message_tracking
      end

      should "use correct format for gauge" do
        @metrics_client.gauge("my_test_metric", 5)
        assert_equal "unicorn.my_test_metric.gauge.prod-fe1:5|g", @metrics_client.sent_message
      end

      should "use correct format for timer" do
        @metrics_client.timer("my_test_metric", 1000)
        assert_equal "unicorn.my_test_metric.timer.prod-fe1:1000|ms", @metrics_client.sent_message
      end

      should "use correct format for counter" do
        @metrics_client.counter("my_test_metric", 1)
        assert_equal "unicorn.my_test_metric.counter.prod-fe1:1|c", @metrics_client.sent_message
      end

      should "use correct format with sub_server_name assigned" do
        Invoca::Metrics.sub_server_name = "9000"
        @metrics_client = metrics_client_with_message_tracking
        @metrics_client.counter("my_test_metric", 1)
        assert_equal "unicorn.my_test_metric.counter.prod-fe1.9000:1|c", @metrics_client.sent_message
        Invoca::Metrics.sub_server_name = nil
      end
    end

    context "in the staging environment" do
      setup do
        stub_metrics_as_staging_unicorn
        @metrics_client = metrics_client_with_message_tracking
      end

      should "use correct format for gauge" do
        @metrics_client.gauge("my_test_metric", 5)
        assert_equal "staging.unicorn.my_test_metric.gauge.staging-full-fe1:5|g", @metrics_client.sent_message
      end

      should "use correct format for timer" do
        @metrics_client.timer("my_test_metric", 1000)
        assert_equal "staging.unicorn.my_test_metric.timer.staging-full-fe1:1000|ms", @metrics_client.sent_message
      end

      should "use correct format for counter" do
        @metrics_client.counter("my_test_metric", 1)
        assert_equal "staging.unicorn.my_test_metric.counter.staging-full-fe1:1|c", @metrics_client.sent_message
      end
    end

  end

  context "reporting to statsd" do
    setup do
      stub_metrics_as_production_unicorn
      @metrics_client = metrics_client_with_message_tracking
    end

    context "gauge" do
      should "send the metric to the socket" do
        @metrics_client.gauge("test_metric", 5)
        assert_equal "unicorn.test_metric.gauge.prod-fe1:5|g", @metrics_client.sent_message
      end

      [nil, ''].each do |value|
        should "fail if metric name is #{value.inspect}" do
          assert_raises(ArgumentError, /Must specify a metric name/) do
            @metrics_client.gauge(value, 5)
          end
        end
      end

    end

    context "counter" do
      should "send the metric to the socket" do
        @metrics_client.counter("test_metric")
        assert_equal "unicorn.test_metric.counter.prod-fe1:1|c", @metrics_client.sent_message
      end

      [nil, ''].each do |value|
        should "fail if metric name is #{value.inspect}" do
          assert_raises(ArgumentError, /Must specify a metric name/) do
            @metrics_client.counter(value)
          end
        end
      end
    end

    context "increment" do
      should "send the metric to the socket" do
        @metrics_client.increment("test_metric")
        assert_equal "unicorn.test_metric.counter.prod-fe1:1|c", @metrics_client.sent_message
      end

      [nil, ''].each do |value|
        should "fail if metric name is #{value.inspect}" do
          assert_raises(ArgumentError, /Must specify a metric name/) do
            @metrics_client.increment(value)
          end
        end
      end
    end

    context "decrement" do
      should "send the metric to the socket" do
        @metrics_client.decrement("test_metric")
        assert_equal "unicorn.test_metric.counter.prod-fe1:-1|c", @metrics_client.sent_message
      end

      [nil, ''].each do |value|
        should "fail if metric name is #{value.inspect}" do
          assert_raises(ArgumentError, /Must specify a metric name/) do
            @metrics_client.decrement(value)
          end
        end
      end
    end

    context "set" do
      should "send the metric to the socket" do
        @metrics_client.set("login", "joe@example.com")
        assert_equal "unicorn.login.prod-fe1:joe@example.com|s", @metrics_client.sent_message
      end

      [nil, ''].each do |value|
        should "fail if metric name is #{value.inspect}" do
          assert_raises(ArgumentError, /Must specify a metric name/) do
            @metrics_client.set(value, 5)
          end
        end
      end
    end

    context "timer" do
      should "send a specified millisecond metric value to the socket" do
        @metrics_client.timer("test_metric", 15000)
        assert_equal "unicorn.test_metric.timer.prod-fe1:15000|ms", @metrics_client.sent_message
      end

      should "send a millisecond metric value based on block to the socket" do
        @metrics_client.timer("test_metric") { 1 + 1 }
        assert_match(/test_metric.timer:[0-9]*|ms/, @metrics_client.sent_message)
      end

      should "send correct second metric value based on block" do
        stub(@metrics_client).time { [nil, 5000] }
        @metrics_client.timer("unicorn.test_metric.prod-fe1") { 1 + 1 }
      end

      [nil, ''].each do |value|
        should "fail if metric name is #{value.inspect}" do
          assert_raises(ArgumentError, /Must specify a metric name/) do
            @metrics_client.timer(value, 5)
          end
        end
      end

      should "fail if not passed milliseconds value or block exclusively" do
        assert_raises(ArgumentError, /Must pass exactly one of milliseconds or block./) do
          @metrics_client.timer("test", 5) { 1 + 1 }
        end
        assert_raises(ArgumentError, /Must pass exactly one of milliseconds or block./) do
          @metrics_client.timer("test")
        end
      end
    end

    context "transmit" do
      should "send the message" do
        @metrics_client.transmit("Something bad happened.", { :custom_data => "12:00pm" })
      end
    end

    context "Statsd Extension" do
      should "connect the socket so we don't do extra DNS queries" do
        socket = @metrics_client.send(:socket)
        socket.send("test message", 0) # Will fail with destination address required if not connected
      end

      should "use a bound udp socket to connect to statsd" do
        begin
          addr = @metrics_client.send(:socket).remote_address
          assert_equal '127.0.0.1', addr.ip_address
          assert_equal 8125, addr.ip_port
        rescue Errno::ENOTCONN => bad
        end
        assert_nil bad, "Socket should have been connected"
      end

     should "use a new socket per Thread" do
        main_socket = @metrics_client.send(:socket)
        new_thread = Thread.new do
          thread_socket = @metrics_client.send(:socket)
          assert main_socket.fileno != thread_socket.fileno
        end
        new_thread.join
      end

      should "not use a new socket per Fiber" do
        main_socket = @metrics_client.send(:socket)
        new_fiber = Fiber.new do
          fiber_socket = @metrics_client.send(:socket)
          Fiber.yield main_socket.fileno == fiber_socket.fileno
        end
        result = new_fiber.resume
        assert result, "The file numbers should be equal"
      end
    end
  end

end
