# frozen_string_literal: true

describe Invoca::Metrics::Source do
  # use this class to test the Metrics functionality as a mixed-in module
  # the idea is that it mixes in and uses the Metrics module just like any other class would
  class ExampleMetricTester
    include Invoca::Metrics::Source

    class << self
      def clear_metrics
        @metrics     = nil
        @metrics_for = nil
      end
    end

    def gauge_trigger(name, value)
      metrics.gauge(name, value)
    end

    def counter_trigger(name)
      metrics.counter(name)
    end

    def timer_trigger(name, milliseconds = nil, &block)
      metrics.timer(name, milliseconds, &block)
    end

    def increment_trigger(name)
      metrics.increment(name)
    end

    def decrement_trigger(name)
      metrics.decrement(name)
    end

    def batch_trigger(&block)
      metrics.batch(&block)
    end

    def set_trigger(name, value)
      metrics.set(name, value)
    end

    # TODO: - implement transmit method
    # def transmit_trigger(name, extra_data)
    #   metrics.transmit(name, extra_data)
    # end
  end

  describe "as a module mixin" do
    let(:sub_server_name) { nil }
    let(:config) { {} }
    let(:default_config_key) { nil }

    subject { ExampleMetricTester.new }

    before(:each) do
      stub_metrics_as_production_unicorn

      Invoca::Metrics.sub_server_name = sub_server_name
      Invoca::Metrics.config = config
      Invoca::Metrics.default_config_key = default_config_key

      subject.metrics.extend(ExposeStatsdClient)
    end

    after(:each) { ExampleMetricTester.clear_metrics }

    describe "metrics clients" do
      let(:sub_server_name) { "default_sub_server_name" }
      let(:default_config_key) { :deploy_group }
      let(:config) do
        {
          deploy_group: {
            statsd_host: "255.0.0.123"
          },
          region: {
            statsd_host: "255.0.0.456"
          }
        }
      end

      describe "#metrics_namespace" do
        after(:each) { subject.class.metrics_namespace(nil) }

        it "creates a metric client with the provided namespace" do
          subject.class.metrics_namespace("different_namespace")
          expect(subject.metrics.namespace).to eq("different_namespace")
        end

        it "returns a different metric client when a different namespace is provided" do
          initial_client = subject.metrics
          subject.class.metrics_namespace("different_namespace")
          namespaced_client = subject.metrics

          expect(initial_client).to_not be(namespaced_client)
          expect(initial_client.namespace).to eq("unicorn")
          expect(namespaced_client.namespace).to eq("different_namespace")
        end
      end

      describe "#metrics" do
        it "returns metrics client for default_config_key" do
          expect(subject.metrics.sub_server_name).to eq("default_sub_server_name")
          expect(subject.metrics.hostname).to eq("255.0.0.123")
        end
      end

      describe "#metrics_for" do
        it "returns metrics client for given config_key" do
          expect(subject.metrics_for(config_key: :region).sub_server_name).to eq("default_sub_server_name")
          expect(subject.metrics_for(config_key: :region).hostname).to eq("255.0.0.456")
        end

        it "returns metrics client for given config_key with namespace provided" do
          expect(subject.metrics_for(config_key: :region, namespace: "different_namespace").sub_server_name).to eq("default_sub_server_name")
          expect(subject.metrics_for(config_key: :region, namespace: "different_namespace").hostname).to eq("255.0.0.456")
          expect(subject.metrics_for(config_key: :region, namespace: "different_namespace").namespace).to eq("different_namespace")
        end

        it "returns the same client when given the same parameters" do
          namespaceless_client = subject.metrics_for(config_key: :region)
          namespaced_client    = subject.metrics_for(config_key: :region, namespace: "different_namespace")

          expect(subject.metrics_for(config_key: :region)).to be(namespaceless_client)
          expect(subject.metrics_for(config_key: :region, namespace: "different_namespace")).to be(namespaced_client)
        end
      end
    end

    it "provides a gauge method" do
      expect(subject.metrics.statsd_client).to receive(:gauge).with("Test.anything.gauge.prod-fe1", 5)
      subject.gauge_trigger("Test.anything", 5)
    end

    it "provides a counter method" do
      expect(subject.metrics.statsd_client).to receive(:count).with("Test.anything.counter.prod-fe1", 1)
      subject.counter_trigger("Test.anything")
    end

    it "provides a timer method" do
      expect(subject.metrics.statsd_client).to receive(:timing).with("Test.anything.timer.prod-fe1", 15)
      subject.timer_trigger("Test.anything", 15)

      expect(subject.metrics.statsd_client).to receive(:timing).with("Test.anything.timer.prod-fe1", kind_of(Numeric), 1)
      subject.timer_trigger("Test.anything") { 1 + 2 }
    end

    it "provides an increment method" do
      expect(subject.metrics.statsd_client).to receive(:count).with("Test.anything.counter.prod-fe1", 1)
      subject.increment_trigger("Test.anything")
    end

    it "provides a decrement method" do
      expect(subject.metrics.statsd_client).to receive(:count).with("Test.anything.counter.prod-fe1", -1)
      subject.decrement_trigger("Test.anything")
    end

    it "provides a batch method" do
      subject.batch_trigger do |batch|
        batch.extend(ExposeStatsdClient)

        expect(batch.statsd_client).to receive(:count).with("Test.stat1.counter.prod-fe1", 1)
        expect(batch.statsd_client).to receive(:count).with("Test.stat2.counter.prod-fe1", 2)

        batch.count("Test.stat1", 1)
        batch.count("Test.stat2", 2)
      end
    end

    it "provides a set method" do
      expect(subject.metrics.statsd_client).to receive(:set).with("Calls.in.otherstattype.prod-fe1", 5)
      subject.set_trigger("Calls.in.otherstattype", 5)
    end

    # TODO: - implement transmit method
    # it "provides a transmit method" do
    #   expect(subject).to respond_to(:transmit_trigger)
    # end
  end
end
