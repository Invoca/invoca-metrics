# frozen_string_literal: true

require 'invoca/metrics'
require 'invoca/metrics/gauge_cache'
require 'sourcify'

describe Invoca::Metrics::GaugeCache do
  let(:statsd_client) { double(Invoca::Metrics::StatsdClient) }

  describe 'class' do
    let(:cache) { double(described_class) }
    let(:client) do
      Invoca::Metrics::Client.new(
        hostname: 'localhost',
        port: '5678',
        cluster_name: 'test_cluster',
        service_name: 'test_service',
        server_label: 'test_label',
        sub_server_name: 'sub_server'
      )
    end

    describe '#register' do
      it 'initializes a new GaugeCache object for the client' do
        expect(described_class).to receive(:new).and_return(cache)
        expect(described_class.register(client.gauge_cache_key, statsd_client)).to eq(cache)
      end
    end
  end

  describe 'initialize' do
    it 'kicks off a new thread for reporting the cached gauges' do
      expect_any_instance_of(described_class).to receive(:report)
      expect_any_instance_of(described_class).to receive(:sleep).with(any_args)
      expect_any_instance_of(described_class).to receive(:loop) { |&loop_block| loop_block.call }
      expect(Thread).to receive(:new) { |&thread_block| thread_block.call }

      described_class.new(statsd_client)
    end
  end

  describe 'instance' do
    let(:metric) { 'test.gauge.metric' }
    let(:value)  { 1 }

    subject { described_class.new(statsd_client) }

    before(:each) { allow(Thread).to receive(:new) }

    describe '#set' do
      it 'should store the value in the cache' do
        expect(subject.cache).to eq({})
        subject.set(metric, value)
        expect(subject.cache).to eq(metric => value)
      end

      describe 'when setting value to nil' do
        let(:value) { nil }

        before(:each) do
          subject.set(metric, 1)
          expect(subject.cache).to eq(metric => 1)
        end

        it 'should set the metric value to nil' do
          subject.set(metric, value)
          expect(subject.cache).to eq(metric => value)
        end
      end
    end

    describe '#report' do
      let(:gauges) do
        {
          'test.gauge.metric.1' => 1,
          'test.gauge.metric.2' => 2,
          'test.gauge.metric.3' => 1
        }
      end

      before(:each) do
        gauges.each { |metric, value| subject.set(metric, value) }
      end

      describe 'with no gauges currently set' do
        let(:gauges) { {} }

        it 'reports nothing' do
          expect(statsd_client).to receive(:batch).and_yield(statsd_client)
          expect(statsd_client).to_not receive(:gauge)
          subject.report
        end
      end

      describe 'with gauges currently set' do
        it 'reports all gauges currently set as gauges on the statsd instance' do
          expect(statsd_client).to receive(:batch).and_yield(statsd_client)
          gauges.each { |metric, value| expect(statsd_client).to receive(:gauge).with(metric, value) }
          subject.report
        end
      end

      describe 'when some gauges set to nil' do
        let(:gauges) do
          {
            'test.gauge.metric.1' => 1,
            'test.gauge.metric.2' => nil,
            'test.gauge.metric.3' => 1
          }
        end

        it 'omits reporting of falsey gauges' do
          expect(statsd_client).to receive(:batch).and_yield(statsd_client)
          gauges.each do |metric, value|
            if value.nil?
              expect(statsd_client).to receive(:gauge).with(metric, value).never
            else
              expect(statsd_client).to receive(:gauge).with(metric, value)
            end
          end
          subject.report
        end
      end
    end
  end

  describe '#reporting_loop_with_rescue' do
    subject { described_class.new(statsd_client) }
    let(:logger) { instance_double(::Logger, "logger") }

    before do
      Invoca::Metrics::Client.logger = logger
      expect_any_instance_of(described_class).to receive(:start_reporting_thread)
    end

    after do
      Invoca::Metrics::Client.logger = nil
    end

    it 'rescues and logs exceptions' do
      expect(subject).to receive(:reporting_loop).and_raise(ScriptError, "error!")
      allow(logger).to receive(:error).with("GaugeCache#reporting_loop_with_rescue rescued exception:\nScriptError: error!")
      allow(statsd_client).to receive(:batch)

      subject.send(:reporting_loop_with_rescue)
    end
  end

  describe '#reporting_loop' do
    subject { described_class.new(statsd_client) }
    let(:reporting_period) { 60.0 }

    before do
      expect(Time).to receive(:now).and_return(0.0)
      expect_any_instance_of(described_class).to receive(:start_reporting_thread)
      expect(subject).to receive(:report)
      expect(subject).to receive(:report) { throw :Done } # to break out of loop
    end

    it 'sleeps the remainder of the publish period' do
      expect(Time).to receive(:now).and_return(3.2)

      expect(subject).to receive(:sleep).with((reporting_period - 3.2).to_i)
      catch(:Done) { subject.send(:reporting_loop) }
    end

    it 'does not sleep a negative amount' do
      expect(Time).to receive(:now).and_return(60.2)

      expect(subject).to_not receive(:sleep)
      expect(subject).to receive(:warn).with("Window to report gauge may have been missed.")
      catch(:Done) { subject.send(:reporting_loop) }
    end

    it 'does not sleep for zero' do
      expect(Time).to receive(:now).and_return(59.9)

      expect(subject).to_not receive(:sleep)
      expect(subject).to receive(:warn).with("Window to report gauge may have been missed.")
      catch(:Done) { subject.send(:reporting_loop) }
    end

    it 'does not warn for service_environment is test' do
      expect(Time).to receive(:now).and_return(60.2)

      expect(subject).to_not receive(:sleep)
      expect(subject).to receive(:service_environment).and_return("test")
      expect(subject).to_not receive(:warn).with("Window to report gauge may have been missed.")
      catch(:Done) { subject.send(:reporting_loop) }
    end
  end
end
