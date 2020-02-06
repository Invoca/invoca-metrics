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

    def timer_trigger(name, milliseconds=nil, &block)
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

    def transmit_trigger(name, extra_data)
      metrics.transmit(name, extra_data)
    end
  end

  describe "as a module mixin" do
    before(:each) do
      stub_metrics_as_production_unicorn
      @metric_tester = ExampleMetricTester.new
      ExampleMetricTester.clear_metrics
      @metric_tester.metrics.extend TrackSentMessage
    end

    describe "metrics clients" do
      before(:each) do
        ExampleMetricTester.clear_metrics
        Invoca::Metrics.sub_server_name = "default_sub_server_name"
        Invoca::Metrics.config = {
          deploy_group: {
            statsd_host: "255.0.0.123"
          },
          region: {
            statsd_host: "255.0.0.456"
          }
        }
        Invoca::Metrics.default_config_key = :deploy_group
      end

      describe "#metrics" do
        it "returns metrics client for default_config_key" do
          metrics_client = @metric_tester.metrics
          expect(metrics_client.sub_server_name).to eq("default_sub_server_name")
          expect(metrics_client.hostname).to eq("255.0.0.123")
        end
      end

      describe "#metrics_for" do
        it "returns metrics client for given config_key" do
          metrics_client = @metric_tester.metrics_for(config_key: :region)
          expect(metrics_client.sub_server_name).to eq("default_sub_server_name")
          expect(metrics_client.hostname).to eq("255.0.0.456")
        end
      end
    end

    it "provides a gauge method" do
      @metric_tester.gauge_trigger("Test.anything", 5)
      expect(@metric_tester.metrics.sent_message).to eq("unicorn.Test.anything.gauge.prod-fe1:5|g")
    end

    it "provides a counter method" do
      @metric_tester.counter_trigger("Test.anything")
      expect(@metric_tester.metrics.sent_message).to eq("unicorn.Test.anything.counter.prod-fe1:1|c")
    end

    it "provides a timer method" do
      @metric_tester.timer_trigger("Test.anything", 15)
      expect(@metric_tester.metrics.sent_message).to eq("unicorn.Test.anything.timer.prod-fe1:15|ms")

      @metric_tester.timer_trigger("Test.anything") { 1 + 2 }
      expect(@metric_tester.metrics.sent_messages.last).to match(/unicorn.prod-fe1.Test.anything.timer:[0-9]*|ms/)
    end

    it "provides an increment method" do
      @metric_tester.increment_trigger("Test.anything")
      expect(@metric_tester.metrics.sent_message).to eq("unicorn.Test.anything.counter.prod-fe1:1|c")
    end

    it "provides a decrement method" do
      @metric_tester.decrement_trigger("Test.anything")
      expect(@metric_tester.metrics.sent_message).to eq("unicorn.Test.anything.counter.prod-fe1:-1|c")
    end

    it "provides a batch method" do
      metric_tester = ExampleMetricTester.new
      metric_tester.metrics.extend TrackSentMessage
      metric_tester.batch_trigger do |batch|
        batch.count("Test.stat1", 1)
        batch.count("Test.stat2", 2)
      end
      expect(metric_tester.metrics.sent_message).to eq("unicorn.Test.stat1.counter.prod-fe1:1|c\nunicorn.Test.stat2.counter.prod-fe1:2|c")
    end

    it "provides a set method" do
      @metric_tester.set_trigger("Calls.in.otherstattype", 5)
      expect(@metric_tester.metrics.sent_message).to eq("unicorn.Calls.in.otherstattype.prod-fe1:5|s")
    end

    it "provides a transmit method" do
      expect(@metric_tester).to respond_to(:transmit_trigger)
    end
  end
end
