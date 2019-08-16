# frozen_string_literal: true

require_relative '../../../test_helper'

describe Invoca::Metrics::DirectMetric do

  class MockTCPSocket
    attr_reader :packets

    def initialize
      @packets = []
    end

    def send(message, _flags)
      @packets << message
    end
  end

  def stubs_tcp_socket(target_host: Invoca::Metrics::DirectMetric::DEFAULT_HOST, target_port: Invoca::Metrics::DirectMetric::DEFAULT_PORT)
    @socket = MockTCPSocket.new
    mock(TCPSocket).open(target_host, target_port).yields(@socket)
  end

  context "direct metrics" do
    setup do
      Time.zone = "Pacific Time (US & Canada)"
      Time.now_override = Time.zone.local(2014,4,21)
    end

    context "metric definition" do

      should "allow metrics to specify a tick" do
        metric = Invoca::Metrics::DirectMetric.new("my.new.metric", 5, 400000201)

        assert_equal "my.new.metric", metric.name
        assert_equal 5,               metric.value
        assert_equal 400000201,       metric.tick

        assert_equal "my.new.metric 5 400000201", metric.to_s
      end

      should "allow the tick to be created for the metric" do
        metric = Invoca::Metrics::DirectMetric.new("my.new.metric", 5)

        assert_equal "my.new.metric", metric.name
        assert_equal 5,               metric.value
        assert_equal 1398063600,      metric.tick

      end

      should "round the tick to the nearest minute" do
        Time.now_override = Time.zone.local(2014,4,21) + 59.seconds
        assert_equal 1398063600,   Invoca::Metrics::DirectMetric.new("my.new.metric", 5).tick

        Time.now_override = Time.zone.local(2014,4,21) + 61.seconds
        assert_equal 1398063660,   Invoca::Metrics::DirectMetric.new("my.new.metric", 5).tick
      end
    end

    context "metric_firing" do
      should "Report a single metric with the proper boiler plate" do
        metric = Invoca::Metrics::DirectMetric.new("my.new.metric", 5)

        stubs_tcp_socket

        Invoca::Metrics::DirectMetric.report(metric)

        assert_equal 1, @socket.packets.size
        assert_equal "my.new.metric 5 1398063600\n", @socket.packets.first
      end

      should "report multiple messages" do
        metrics = (1..5).map { |id| Invoca::Metrics::DirectMetric.new("my.new.metric#{id}", id) }

        stubs_tcp_socket

        Invoca::Metrics::DirectMetric.report(metrics)

        expected = "my.new.metric1 1 1398063600\nmy.new.metric2 2 1398063600\nmy.new.metric3 3 1398063600\nmy.new.metric4 4 1398063600\nmy.new.metric5 5 1398063600\n"
        assert_equal expected, @socket.packets.first
      end
    end

    context "generate_distribution" do
      should "use the passed in tick" do
        stubs_tcp_socket
        metrics = Invoca::Metrics::DirectMetric.generate_distribution("bob.is.testing",[], 10022)
        Invoca::Metrics::DirectMetric.report(metrics)

        expected = "bob.is.testing.count 0 10022\n"
        assert_equal expected, @socket.packets.first
      end

      should "just report the count when called with an empty list" do
        stubs_tcp_socket
        metrics = Invoca::Metrics::DirectMetric.generate_distribution("bob.is.testing",[])
        Invoca::Metrics::DirectMetric.report(metrics)

        expected = "bob.is.testing.count 0 1398063600\n"
        assert_equal expected, @socket.packets.first
      end

      should "correctly compute min max and median" do
        stubs_tcp_socket
        metrics = Invoca::Metrics::DirectMetric.generate_distribution("bob.is.testing",(0..99).to_a)
        Invoca::Metrics::DirectMetric.report(metrics)

        expected = [
            "bob.is.testing.count 100 1398063600",
            "bob.is.testing.max 99 1398063600",
            "bob.is.testing.min 0 1398063600",
            "bob.is.testing.median 50 1398063600",
            "bob.is.testing.upper_90 90 1398063600"
        ]
        assert_equal expected, @socket.packets.first.split("\n")
      end
    end

    describe "environment configuration" do
      after do
        ENV["DIRECT_METRIC_HOST"] = nil
        ENV["DIRECT_METRIC_PORT"] = nil
      end

      it "allows environment to define DIRECT_METRIC_HOST and DIRECT_METRIC_PORT" do
        target_host = "carbon-relay.test.com"
        target_port = "2003"

        ENV["DIRECT_METRIC_HOST"] = target_host
        ENV["DIRECT_METRIC_PORT"] = target_port

        stubs_tcp_socket(target_host: target_host, target_port: target_port.to_i)

        metric = Invoca::Metrics::DirectMetric.new("my.new.metric", 5)
        Invoca::Metrics::DirectMetric.report(metric)

        assert_equal "my.new.metric 5 1398063600\n", @socket.packets.first
      end
    end
  end
end

