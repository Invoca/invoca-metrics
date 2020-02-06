# frozen_string_literal: true

require_relative '../../../spec_helper'

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

  def stub_tcp_socket(
    target_host: Invoca::Metrics::DirectMetric::DEFAULT_HOST,
    target_port: Invoca::Metrics::DirectMetric::DEFAULT_PORT
  )
    double(TCPSocket).tap do |socket|
      allow(TCPSocket).to receive(:open).with(target_host, target_port).and_yield(socket)
    end
  end

  describe "direct metrics" do
    let(:name) { "my.new.metric" }
    let(:value) { 5 }
    let(:tick) { nil }

    subject(:metric) { Invoca::Metrics::DirectMetric.new(name, value, tick) }

    before(:each) do
      Time.zone = "Pacific Time (US & Canada)"
      Time.now_override = Time.zone.local(2014, 4, 21)
    end

    describe "metric definition" do
      describe "with tick specified" do
        let(:tick) { 400_000_201 }

        it "prints the specified tick with the metric data" do
          expect(metric.name).to eq(name)
          expect(metric.value).to eq(value)
          expect(metric.tick).to eq(tick)
          expect(metric.to_s).to eq("#{name} #{value} #{tick}")
        end
      end

      it "allows the tick to be created for the metric" do
        expect(metric.name).to eq(name)
        expect(metric.value).to eq(value)
        expect(metric.tick).to eq(1_398_063_600)
        expect(metric.to_s).to eq("#{name} #{value} 1398063600")
      end

      describe "when between minutes" do
        it "rounds the tick to the nearest minute" do
          Time.now_override = Time.zone.local(2014, 4, 21) + 59.seconds
          expect(Invoca::Metrics::DirectMetric.new(name, value).tick).to eq(1_398_063_600)

          Time.now_override = Time.zone.local(2014, 4, 21) + 61.seconds
          expect(Invoca::Metrics::DirectMetric.new(name, value).tick).to eq(1_398_063_660)
        end
      end
    end

    describe "metric_firing" do
      let(:socket) { stub_tcp_socket }

      it "reports a single metric with the proper boiler plate" do
        expect(socket).to receive(:send).with("my.new.metric 5 1398063600\n", anything)
        Invoca::Metrics::DirectMetric.report(metric)
      end

      it "reports multiple messages" do
        metrics = (1..5).map { |id| Invoca::Metrics::DirectMetric.new("my.new.metric#{id}", id) }

        expect(socket).to receive(:send).with("#{metrics.join("\n")}\n", anything)
        Invoca::Metrics::DirectMetric.report(metrics)
      end
    end

    describe "generate_distribution" do
      let(:name) { "bob.is.testing" }
      let(:value) { [] }
      let(:tick) { nil }
      let(:expected) { "bob.is.testing.count 0 1398063600\n" }
      let(:socket) { stub_tcp_socket }

      subject(:metrics) { Invoca::Metrics::DirectMetric.generate_distribution(name, value, tick) }

      describe "when a tick is provided" do
        let(:tick) { 10022 }
        let(:expected) { "bob.is.testing.count 0 10022\n" }

        it "records the tick given" do
          expect(socket).to receive(:send).with(expected, anything)
          Invoca::Metrics::DirectMetric.report(metrics)
        end
      end

      it "reports just the count when called with an empty list" do
        expect(socket).to receive(:send).with(expected, anything)
        Invoca::Metrics::DirectMetric.report(metrics)
      end

      describe "with values provided" do
        let(:value) { (0..99).to_a }
        let(:expected) do
          [
            "bob.is.testing.count 100 1398063600",
            "bob.is.testing.max 99 1398063600",
            "bob.is.testing.min 0 1398063600",
            "bob.is.testing.median 50 1398063600",
            "bob.is.testing.upper_90 90 1398063600",
            ""
          ].join("\n")
        end

        it "correctly computes min max and median" do
          expect(socket).to receive(:send).with(expected, anything)
          Invoca::Metrics::DirectMetric.report(metrics)
        end
      end
    end

    describe "environment configuration" do
      after(:each) do
        ENV["DIRECT_METRIC_HOST"] = nil
        ENV["DIRECT_METRIC_PORT"] = nil
      end

      it "allows environment to define DIRECT_METRIC_HOST and DIRECT_METRIC_PORT" do
        target_host = "carbon-relay.test.com"
        target_port = "2003"

        ENV["DIRECT_METRIC_HOST"] = target_host
        ENV["DIRECT_METRIC_PORT"] = target_port

        socket = stub_tcp_socket(target_host: target_host, target_port: target_port.to_i)
        metric = Invoca::Metrics::DirectMetric.new("my.new.metric", 5)
        expect(socket).to receive(:send).with("my.new.metric 5 1398063600\n", anything)

        Invoca::Metrics::DirectMetric.report(metric)
      end
    end
  end
end

