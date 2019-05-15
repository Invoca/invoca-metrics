# frozen_string_literal: true

require_relative '../../../test_helper'

describe Invoca::Metrics::DirectMetric do

  def stubs_sensu_udp_socket
    @packets = []
    mock.instance_of(UDPSocket).send.with_any_args do |message,flags,host,port|
      @packets << message
      assert_equal 0,                                         flags
      assert_equal Invoca::Metrics::DirectMetric::SENSU_HOST, host
      assert_equal Invoca::Metrics::DirectMetric::SENSU_PORT, port
    end
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

        stubs_sensu_udp_socket

        Invoca::Metrics::DirectMetric.report(metric)

        assert_equal 1, @packets.size

        parsed_message = ActiveSupport::JSON.decode( @packets.first )

        # Content
        assert_equal "my.new.metric 5 1398063600\n", parsed_message['output']

        # Boiler plate
        assert_equal 'application_metrics', parsed_message['name']
        assert_equal 'metric', parsed_message['type']
        assert_equal 'rr_metrics', parsed_message['command']
        assert_equal ["graphite"], parsed_message['handlers']
      end

      should "report multiple messages" do
        metrics = (1..5).map { |id| Invoca::Metrics::DirectMetric.new("my.new.metric#{id}", id) }

        stubs_sensu_udp_socket

        Invoca::Metrics::DirectMetric.report(metrics)
        parsed_message = ActiveSupport::JSON.decode( @packets.first )

        expected = "my.new.metric1 1 1398063600\nmy.new.metric2 2 1398063600\nmy.new.metric3 3 1398063600\nmy.new.metric4 4 1398063600\nmy.new.metric5 5 1398063600\n"
        assert_equal expected, parsed_message['output']
      end
    end

    context "generate_distribution" do
      should "use the passed in tick" do
        stubs_sensu_udp_socket
        metrics = Invoca::Metrics::DirectMetric.generate_distribution("bob.is.testing",[], 10022)
        Invoca::Metrics::DirectMetric.report(metrics)
        parsed_message = ActiveSupport::JSON.decode( @packets.first )

        expected = "bob.is.testing.count 0 10022\n"
        assert_equal expected, parsed_message['output']
      end

      should "just report the count when called with an empty list" do
        stubs_sensu_udp_socket
        metrics = Invoca::Metrics::DirectMetric.generate_distribution("bob.is.testing",[])
        Invoca::Metrics::DirectMetric.report(metrics)
        parsed_message = ActiveSupport::JSON.decode( @packets.first )

        expected = "bob.is.testing.count 0 1398063600\n"
        assert_equal expected, parsed_message['output']
      end

      should "correctly compute min max and median" do
        stubs_sensu_udp_socket
        metrics = Invoca::Metrics::DirectMetric.generate_distribution("bob.is.testing",(0..99).to_a)
        Invoca::Metrics::DirectMetric.report(metrics)
        parsed_message = ActiveSupport::JSON.decode( @packets.first )

        expected = [
            "bob.is.testing.count 100 1398063600",
            "bob.is.testing.max 99 1398063600",
            "bob.is.testing.min 0 1398063600",
            "bob.is.testing.median 50 1398063600",
            "bob.is.testing.upper_90 90 1398063600"
        ]
        assert_equal expected, parsed_message['output'].split("\n")
      end
    end
  end
end

