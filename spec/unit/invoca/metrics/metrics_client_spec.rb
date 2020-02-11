# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Invoca::Metrics::Client do
  describe "initialization" do
    before(:each) { stub_metrics_as_production_unicorn }

    it "properly construct with params and statsd both turned on" do
      custom_host     = "127.0.0.2"
      custom_port     = 8300
      cluster_name    = "test_cluster"
      service_name    = "test_service"
      server_name     = "test_server"
      sub_server_name = "test_sub_server"
      metrics_client  = Invoca::Metrics::Client.new(custom_host, custom_port, cluster_name, service_name, server_name, sub_server_name)

      expect(metrics_client.hostname).to eq(custom_host)
      expect(metrics_client.port).to eq(custom_port)
      expect(metrics_client.namespace).to eq("test_cluster.test_service")
    end

    it "properly construct with defaults such that statsd are enabled" do
      metrics_client = Invoca::Metrics::Client.metrics
      expect(metrics_client.hostname).to eq(Invoca::Metrics::Client::STATSD_DEFAULT_HOSTNAME)
      expect(metrics_client.port).to eq(Invoca::Metrics::Client::STATSD_DEFAULT_PORT)
      expect(metrics_client.namespace).to eq("unicorn")
    end

    it "properly construct with configured statsd connection information" do
      Invoca::Metrics.statsd_host = "127.0.0.10"
      Invoca::Metrics.statsd_port = 1234
      metrics_client              = Invoca::Metrics::Client.metrics
      expect(metrics_client.hostname).to eq("127.0.0.10")
      expect(metrics_client.port).to eq(1234)
    end

    it "properly construct with configured statsd config for default_config_key" do
      stub_metrics(
        server_name:        "prod-fe1",
        service_name:       "unicorn",
        statsd_host:        "127.0.0.1",
        statsd_port:        443,
        sub_server_name:    "sub_server_1",
        config:             {
          deploy_group: {
            server_name: "primary",
            statsd_host: "128.0.0.2",
            statsd_port: 3001
          }
        },
        default_config_key: :deploy_group
      )
      metrics_client = Invoca::Metrics::Client.metrics
      expect(metrics_client.hostname).to eq("128.0.0.2")
      expect(metrics_client.port).to eq(3001)
      expect(metrics_client.server_label).to eq("primary")
      expect(metrics_client.sub_server_name).to eq("sub_server_1")
    end

    it "construct with given args along with default args" do
      Invoca::Metrics.statsd_host = "127.0.0.10"
      Invoca::Metrics.statsd_port = 1234
      metrics_client              = Invoca::Metrics::Client.metrics(statsd_host: "127.0.0.255", statsd_port: 5678)
      expect(metrics_client.hostname).to eq("127.0.0.255")
      expect(metrics_client.port).to eq(5678)
    end

    it "starts a gauge cache reporting thread for itself" do
      Invoca::Metrics.statsd_host = "127.0.0.10"
      Invoca::Metrics.statsd_port = 1234

      expect(Invoca::Metrics::GaugeCache).to receive(:start_report_thread)

      Invoca::Metrics::Client.metrics(statsd_host: "127.0.0.255", statsd_port: 5678)
    end
  end

  describe "#server_name" do
    it "return server_label for backwards compatibility" do
      stub_metrics_as_production_unicorn
      metrics_client = Invoca::Metrics::Client.metrics
      expect(metrics_client.server_label).to eq(metrics_client.server_name)
      expect(metrics_client.server_name).to eq("prod-fe1")
    end
  end

  describe "reporting to statsd" do
    describe "in the production environment" do
      before(:each) do
        stub_metrics_as_production_unicorn
        @metrics_client = metrics_client_with_message_tracking
      end

      it "use correct format for gauge" do
        @metrics_client.gauge("my_test_metric", 5)
        expect(@metrics_client.sent_message).to eq("unicorn.my_test_metric.gauge.prod-fe1:5|g")
      end

      it "use correct format for timer" do
        @metrics_client.timer("my_test_metric", 1000)
        expect(@metrics_client.sent_message).to eq("unicorn.my_test_metric.timer.prod-fe1:1000|ms")
      end

      it "use correct format for counter" do
        @metrics_client.counter("my_test_metric", 1)
        expect(@metrics_client.sent_message).to eq("unicorn.my_test_metric.counter.prod-fe1:1|c")
      end

      it "use correct format with sub_server_name assigned" do
        Invoca::Metrics.sub_server_name = "9000"
        @metrics_client                 = metrics_client_with_message_tracking
        @metrics_client.counter("my_test_metric", 1)
        expect(@metrics_client.sent_message).to eq("unicorn.my_test_metric.counter.prod-fe1.9000:1|c")
        Invoca::Metrics.sub_server_name = nil
      end
    end

    describe "in the staging environment" do
      before(:each) do
        stub_metrics_as_staging_unicorn
        @metrics_client = metrics_client_with_message_tracking
      end

      it "use correct format for gauge" do
        @metrics_client.gauge("my_test_metric", 5)
        expect(@metrics_client.sent_message).to eq("staging.unicorn.my_test_metric.gauge.staging-full-fe1:5|g")
      end

      it "use correct format for timer" do
        @metrics_client.timer("my_test_metric", 1000)
        expect(@metrics_client.sent_message).to eq("staging.unicorn.my_test_metric.timer.staging-full-fe1:1000|ms")
      end

      it "use correct format for counter" do
        @metrics_client.counter("my_test_metric", 1)
        expect(@metrics_client.sent_message).to eq("staging.unicorn.my_test_metric.counter.staging-full-fe1:1|c")
      end
    end
  end

  describe "reporting to statsd" do
    before(:each) do
      stub_metrics_as_production_unicorn
      @metrics_client = metrics_client_with_message_tracking
    end

    describe "gauge" do
      it "send the metric to the socket" do
        @metrics_client.gauge("test_metric", 5)
        expect(@metrics_client.sent_message).to eq("unicorn.test_metric.gauge.prod-fe1:5|g")
      end

      [nil, ""].each do |value|
        it "fail if metric name is #{value.inspect}" do
          expect { @metrics_client.gauge(value, 5) }.to raise_error(ArgumentError, /Must specify a metric name/)
        end
      end
    end

    describe "counter" do
      it "send the metric to the socket" do
        @metrics_client.counter("test_metric")
        expect(@metrics_client.sent_message).to eq("unicorn.test_metric.counter.prod-fe1:1|c")
      end

      [nil, ""].each do |value|
        it "fail if metric name is #{value.inspect}" do
          expect { @metrics_client.counter(value) }.to raise_error(ArgumentError, /Must specify a metric name/)
        end
      end
    end

    describe "increment" do
      it "send the metric to the socket" do
        @metrics_client.increment("test_metric")
        expect(@metrics_client.sent_message).to eq("unicorn.test_metric.counter.prod-fe1:1|c")
      end

      [nil, ""].each do |value|
        it "fail if metric name is #{value.inspect}" do
          expect { @metrics_client.increment(value) }.to raise_error(ArgumentError, /Must specify a metric name/)
        end
      end
    end

    describe "decrement" do
      it "send the metric to the socket" do
        @metrics_client.decrement("test_metric")
        expect(@metrics_client.sent_message).to eq("unicorn.test_metric.counter.prod-fe1:-1|c")
      end

      [nil, ""].each do |value|
        it "fail if metric name is #{value.inspect}" do
          expect { @metrics_client.decrement(value) }.to raise_error(ArgumentError, /Must specify a metric name/)
        end
      end
    end

    describe "set" do
      it "send the metric to the socket" do
        @metrics_client.set("login", "joe@example.com")
        expect(@metrics_client.sent_message).to eq("unicorn.login.prod-fe1:joe@example.com|s")
      end

      [nil, ""].each do |value|
        it "fail if metric name is #{value.inspect}" do
          expect { @metrics_client.set(value, 5) }.to raise_error(ArgumentError, /Must specify a metric name/)
        end
      end
    end

    describe "timer" do
      it "send a specified millisecond metric value to the socket" do
        @metrics_client.timer("test_metric", 15000)
        expect(@metrics_client.sent_message).to eq("unicorn.test_metric.timer.prod-fe1:15000|ms")
      end

      it "send a millisecond metric value based on block to the socket" do
        @metrics_client.timer("test_metric") { (1 + 1) }
        expect(@metrics_client.sent_message).to match(/test_metric.timer:[0-9]*|ms/)
      end

      it "send correct second metric value based on block" do
        allow(@metrics_client).to receive(:time).and_return([nil, 5000])
        @metrics_client.timer("unicorn.test_metric.prod-fe1") { (1 + 1) }
      end

      it "return the value from the block" do
        expect(@metrics_client.timer("unicorn.test_metric.prod-fe1") { (1 + 1) }).to eq(2)
      end

      it "return both the value from the block and the timing if specified" do
        allow(@metrics_client).to receive(:time).and_return([2, 5000])
        result_from_block, timing = @metrics_client.timer("unicorn.test_metric.prod-fe1", return_timing: true) do
          (1 + 1)
        end
        expect(result_from_block).to eq(2)
        expect(timing).to eq(5000)
      end

      [nil, ""].each do |value|
        it "fail if metric name is #{value.inspect}" do
          expect { @metrics_client.timer(value, 5) }.to raise_error(ArgumentError, /Must specify a metric name/)
        end
      end

      it "fail if not passed milliseconds value or block exclusively" do
        expect { @metrics_client.timer("test", 5) { (1 + 1) } }.to raise_error(ArgumentError, /Must pass exactly one of milliseconds or block/)

        expect { @metrics_client.timer("test") }.to raise_error(ArgumentError, /Must pass exactly one of milliseconds or block/)
      end
    end

    describe "transmit" do
      it "send the message" do
        @metrics_client.transmit("Something bad happened.", custom_data: "12:00pm")
      end
    end

    describe "Statsd Extension" do
      it "connect the socket so we don't do extra DNS queries" do
        socket = @metrics_client.send(:socket)
        socket.send("test message", 0)
      end

      it "use a bound udp socket to connect to statsd" do
        addr = @metrics_client.send(:socket).remote_address
        expect(addr.ip_address).to eq("127.0.0.1")
        expect(addr.ip_port).to eq(8125)
      end

      it "use a new socket per Thread" do
        main_socket = @metrics_client.send(:socket)
        new_thread  = Thread.new do
          thread_socket = @metrics_client.send(:socket)
          expect(main_socket.fileno != thread_socket.fileno).to be_truthy
        end
        new_thread.join
      end

      it "not use a new socket per Fiber" do
        main_socket = @metrics_client.send(:socket)
        new_fiber   = Fiber.new do
          fiber_socket = @metrics_client.send(:socket)
          Fiber.yield((main_socket.fileno == fiber_socket.fileno))
        end
        expect(new_fiber.resume).to be_truthy
      end
    end
  end
end
