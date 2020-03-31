# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Invoca::Metrics::Client do
  describe "initialization" do
    before(:each) { stub_metrics_as_production_unicorn }

    it "properly constructs with params and statsd both turned on" do
      custom_host     = "127.0.0.2"
      custom_port     = 8300
      cluster_name    = "test_cluster"
      service_name    = "test_service"
      server_name     = "test_server"
      sub_server_name = "test_sub_server"

      metrics_client = Invoca::Metrics::Client.new(
        hostname:        custom_host,
        port:            custom_port,
        cluster_name:    cluster_name,
        service_name:    service_name,
        server_label:    server_name,
        sub_server_name: sub_server_name
      )

      expect(metrics_client.hostname).to eq(custom_host)
      expect(metrics_client.port).to eq(custom_port)
      expect(metrics_client.namespace).to eq("test_cluster.test_service")
    end

    it "properly constructs with a namespace provided" do
      custom_host     = "127.0.0.2"
      custom_port     = 8300
      namespace       = "separate_namespace"

      metrics_client = Invoca::Metrics::Client.new(
        hostname:        custom_host,
        port:            custom_port,
        cluster_name:    "test_cluster",
        service_name:    "test_service",
        server_label:    "test_server",
        sub_server_name: "test_sub_server",
        namespace:       namespace
      )

      expect(metrics_client.hostname).to eq(custom_host)
      expect(metrics_client.port).to eq(custom_port)
      expect(metrics_client.namespace).to eq(namespace)
    end

    it "properly constructs with defaults such that statsd are enabled" do
      metrics_client = Invoca::Metrics::Client.metrics
      expect(metrics_client.hostname).to eq(Invoca::Metrics::Client::STATSD_DEFAULT_HOSTNAME)
      expect(metrics_client.port).to eq(Invoca::Metrics::Client::STATSD_DEFAULT_PORT)
      expect(metrics_client.namespace).to eq("unicorn")
    end

    it "properly constructs with configured statsd connection information" do
      Invoca::Metrics.statsd_host = "127.0.0.10"
      Invoca::Metrics.statsd_port = 1234
      metrics_client              = Invoca::Metrics::Client.metrics
      expect(metrics_client.hostname).to eq("127.0.0.10")
      expect(metrics_client.port).to eq(1234)
    end

    it "properly constructs with configured statsd config for default_config_key" do
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

    it "constructs with given args along with default args" do
      Invoca::Metrics.statsd_host = "127.0.0.10"
      Invoca::Metrics.statsd_port = 1234
      metrics_client              = Invoca::Metrics::Client.metrics(statsd_host: "127.0.0.255", statsd_port: 5678)
      expect(metrics_client.hostname).to eq("127.0.0.255")
      expect(metrics_client.port).to eq(5678)
    end

    it "registers a gauge cache for itself" do
      Invoca::Metrics.statsd_host = "127.0.0.10"
      Invoca::Metrics.statsd_port = 1234

      expected_cache_key = ["127.0.0.255", 5678, nil, "unicorn", "unicorn", "prod-fe1", nil]
      expect(Invoca::Metrics::GaugeCache).to receive(:register).with(expected_cache_key, instance_of(Invoca::Metrics::StatsdClient))

      Invoca::Metrics::Client.metrics(statsd_host: "127.0.0.255", statsd_port: 5678)
    end
  end

  describe "#logger" do
    it "allows assignment of StatsdClient logger through Invoca::Metrics::Client" do
      logger = Logger.new(STDOUT)
      expect(described_class.logger).to_not be(logger)
      expect(described_class.logger).to be(Invoca::Metrics::StatsdClient.logger)

      described_class.logger = logger

      expect(described_class.logger).to be(logger)
      expect(Invoca::Metrics::StatsdClient.logger).to be(logger)
    end
  end

  describe "#log_send_failures" do
    it "allows accessing log_send_failures through Invoca::Metrics::Client" do
      described_class.log_send_failures = false
      expect(described_class.log_send_failures).to eq(false)
      expect(Invoca::Metrics::StatsdClient.log_send_failures).to eq(false)
      described_class.log_send_failures = true
      expect(described_class.log_send_failures).to eq(true)
      expect(Invoca::Metrics::StatsdClient.log_send_failures).to eq(true)
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
    subject { Invoca::Metrics::Client.metrics }

    describe "in the production environment" do
      let(:sub_server_name) { nil }

      before(:each) do
        stub_metrics_as_production_unicorn
        Invoca::Metrics.sub_server_name = sub_server_name
        expect(subject.instance_variable_get(:@statsd_client).prefix).to eq('unicorn.')
      end

      it "use correct format for gauge" do
        expect(subject.instance_variable_get(:@statsd_client)).to receive(:gauge).with("my_test_metric.gauge.prod-fe1", 5)

        subject.gauge("my_test_metric", 5)
        expect(subject.gauge_cache.cache).to include("my_test_metric.gauge.prod-fe1" => 5)
      end

      it "use correct format for timer" do
        expect(subject.instance_variable_get(:@statsd_client)).to receive(:timing).with("my_test_metric.timer.prod-fe1", 1000)
        subject.timer("my_test_metric", 1000)
      end

      it "use correct format for counter" do
        expect(subject.instance_variable_get(:@statsd_client)).to receive(:count).with("my_test_metric.counter.prod-fe1", 1)
        subject.counter("my_test_metric", 1)
      end

      describe "with sub_server_name set" do
        let(:sub_server_name) { "9000" }

        it "uses the correct formatting" do
          subject = Invoca::Metrics::Client.metrics
          expect(subject.instance_variable_get(:@statsd_client)).to receive(:count).with("my_test_metric.counter.prod-fe1.9000", 1)
          subject.counter("my_test_metric", 1)
        end
      end
    end

    describe "in the staging environment" do
      before(:each) do
        stub_metrics_as_staging_unicorn
        expect(subject.instance_variable_get(:@statsd_client).prefix).to eq('staging.unicorn.')
      end

      it "use correct format for gauge" do
        expect(subject.instance_variable_get(:@statsd_client)).to receive(:gauge).with("my_test_metric.gauge.staging-full-fe1", 5)

        subject.gauge("my_test_metric", 5)
        expect(subject.gauge_cache.cache).to include("my_test_metric.gauge.staging-full-fe1" => 5)
      end

      it "use correct format for timer" do
        expect(subject.instance_variable_get(:@statsd_client)).to receive(:timing).with("my_test_metric.timer.staging-full-fe1", 1000)
        subject.timer("my_test_metric", 1000)
      end

      it "use correct format for counter" do
        expect(subject.instance_variable_get(:@statsd_client)).to receive(:count).with("my_test_metric.counter.staging-full-fe1", 1)
        subject.counter("my_test_metric", 1)
      end
    end

    describe "validations" do
      before(:each) do
        stub_metrics_as_production_unicorn
      end

      describe "gauge" do
        it "send the metric to the statsd client" do
          expect(subject.instance_variable_get(:@statsd_client)).to receive(:gauge).with("my_test_metric.gauge.prod-fe1", 5)

          subject.gauge("my_test_metric", 5)
          expect(subject.gauge_cache.cache).to include("my_test_metric.gauge.prod-fe1" => 5)
        end

        [nil, ""].each do |value|
          it "fail if metric name is #{value.inspect}" do
            expect { subject.gauge(value, 5) }.to raise_error(ArgumentError, /Must specify a metric name/)
          end
        end
      end

      describe "counter" do
        it "send the metric to the socket" do
          expect(subject.instance_variable_get(:@statsd_client)).to receive(:count).with("my_test_metric.counter.prod-fe1", 1)
          subject.counter("my_test_metric", 1)
        end

        [nil, ""].each do |value|
          it "fail if metric name is #{value.inspect}" do
            expect { subject.counter(value) }.to raise_error(ArgumentError, /Must specify a metric name/)
          end
        end
      end

      describe "increment" do
        it "send the metric to the socket" do
          expect(subject.instance_variable_get(:@statsd_client)).to receive(:count).with("test_metric.counter.prod-fe1", 1)
          subject.increment("test_metric")
        end

        [nil, ""].each do |value|
          it "fail if metric name is #{value.inspect}" do
            expect { subject.increment(value) }.to raise_error(ArgumentError, /Must specify a metric name/)
          end
        end
      end

      describe "decrement" do
        it "send the metric to the socket" do
          expect(subject.instance_variable_get(:@statsd_client)).to receive(:count).with("test_metric.counter.prod-fe1", -1)
          subject.decrement("test_metric")
        end

        [nil, ""].each do |value|
          it "fail if metric name is #{value.inspect}" do
            expect { subject.decrement(value) }.to raise_error(ArgumentError, /Must specify a metric name/)
          end
        end
      end

      describe "set" do
        it "send the metric to the socket" do
          expect(subject.instance_variable_get(:@statsd_client)).to receive(:set).with("login.prod-fe1", "joe@example.com")
          subject.set("login", "joe@example.com")
        end

        [nil, ""].each do |value|
          it "fail if metric name is #{value.inspect}" do
            expect { subject.set(value, 5) }.to raise_error(ArgumentError, /Must specify a metric name/)
          end
        end
      end

      describe "timer" do
        it "send a specified millisecond metric value to the socket" do
          expect(subject.instance_variable_get(:@statsd_client)).to receive(:timing).with("test_metric.timer.prod-fe1", 15000)
          subject.timer("test_metric", 15000)
        end

        it "send a millisecond metric value based on block to the socket" do
          expect(subject.instance_variable_get(:@statsd_client)).to receive(:timing).with("test_metric.timer.prod-fe1", kind_of(Numeric), 1)
          subject.timer("test_metric") { (1 + 1) }
        end

        it "send correct second metric value based on block" do
          allow(subject.instance_variable_get(:@statsd_client)).to receive(:time).and_return([nil, 5000])
          subject.timer("unicorn.test_metric.prod-fe1") { (1 + 1) }
        end

        it "return the value from the block" do
          expect(subject.timer("unicorn.test_metric.prod-fe1") { (1 + 1) }).to eq(2)
          expect(subject.timer("unicorn.test_metric.prod-fe1") { ([1] + [1]) }).to eq([1, 1])
        end

        it "return both the value from the block and the timing if specified" do
          allow(subject.instance_variable_get(:@statsd_client)).to receive(:time).and_return([2, 5000])
          result_from_block, timing = subject.timer("unicorn.test_metric.prod-fe1", return_timing: true) do
            (1 + 1)
          end
          expect(result_from_block).to eq(2)
          expect(timing).to eq(5000)
        end

        [nil, ""].each do |value|
          it "fail if metric name is #{value.inspect}" do
            expect { subject.timer(value, 5) }.to raise_error(ArgumentError, /Must specify a metric name/)
          end
        end

        it "fail if not passed milliseconds value or block exclusively" do
          expect { subject.timer("test", 5) { (1 + 1) } }.to raise_error(ArgumentError, /Must pass exactly one of milliseconds or block/)

          expect { subject.timer("test") }.to raise_error(ArgumentError, /Must pass exactly one of milliseconds or block/)
        end
      end

      # TODO: - implement transmit method
      # describe "transmit" do
      #   it "send the message" do
      #     subject.transmit("Something bad happened.", custom_data: "12:00pm")
      #   end
      # end
    end
  end
end
