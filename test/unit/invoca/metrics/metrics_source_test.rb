require File.expand_path('../../../../test_helper',  __FILE__)
require File.expand_path('../../../../helpers/metrics/metrics_test_helpers', __FILE__)

describe Invoca::Metrics::Source do

  include MetricsTestHelpers
  include ::Rails::Dom::Testing::Assertions::SelectorAssertions

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

  context "as a module mixin" do
    setup do
      stub_metrics_as_production_unicorn
      @metric_tester = ExampleMetricTester.new
      ExampleMetricTester.clear_metrics
      @metric_tester.metrics.extend TrackSentMessage
    end

    should "provide a gauge method" do
      @metric_tester.gauge_trigger("Test.anything", 5)
      assert_equal "unicorn.Test.anything.gauge.prod-fe1:5|g", @metric_tester.metrics.sent_message
    end

    should "provide a counter method" do
      @metric_tester.counter_trigger("Test.anything")
      assert_equal "unicorn.Test.anything.counter.prod-fe1:1|c", @metric_tester.metrics.sent_message
    end

    should "provide a timer method" do
      @metric_tester.timer_trigger("Test.anything", 15)
      assert_equal "unicorn.Test.anything.timer.prod-fe1:15|ms", @metric_tester.metrics.sent_message
      @metric_tester.timer_trigger("Test.anything") { test = 1 + 1 }
      assert /unicorn.prod-fe1.Test.anything.timer:[0-9]*|ms/ =~ @metric_tester.metrics.sent_messages.last
    end

    should "provide an increment method" do
      @metric_tester.increment_trigger("Test.anything")
      assert_equal "unicorn.Test.anything.counter.prod-fe1:1|c", @metric_tester.metrics.sent_message
    end

    should "provide a decrement method" do
      @metric_tester.decrement_trigger("Test.anything")
      assert_equal "unicorn.Test.anything.counter.prod-fe1:-1|c", @metric_tester.metrics.sent_message
    end

    should "provide a batch method" do
      metric_tester = ExampleMetricTester.new
      metric_tester.metrics.extend TrackSentMessage
      metric_tester.batch_trigger do |batch|
        batch.count("Test.stat1", 1)
        batch.count("Test.stat2", 2)
      end
      assert_equal "unicorn.Test.stat1.counter.prod-fe1:1|c\nunicorn.Test.stat2.counter.prod-fe1:2|c",  metric_tester.metrics.sent_message
    end

    should "provide a set method" do
      @metric_tester.set_trigger("Calls.in.otherstattype", 5)
      assert_equal "unicorn.Calls.in.otherstattype.prod-fe1:5|s", @metric_tester.metrics.sent_message
    end

    should "provide a transmit method" do
      @metric_tester.transmit_trigger("Something bad has happened.", { :custom_data => "3:00pm" })
    end
  end
end
