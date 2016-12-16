require File.expand_path('../../../../test_helper',  __FILE__)
require File.expand_path('../../../../helpers/metrics/metrics_test_helpers', __FILE__)

describe Invoca::Metrics::Client do

  include MetricsTestHelpers
  if ::Rails.const_defined?(:Dom)
    include ::Rails::Dom::Testing::Assertions::SelectorAssertions
  else
    include ActionDispatch::Assertions::SelectorAssertions
  end

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
        assert /test_metric.timer:[0-9]*|ms/ =~ @metrics_client.sent_message
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
    end
  end

end
