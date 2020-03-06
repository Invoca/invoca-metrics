# frozen_string_literal: true

require 'sourcify'

describe Invoca::Metrics::GaugeCache do
  let(:statsd) { double(Invoca::Metrics::StatsdWithPersistentConnection) }

  describe 'class' do
    let(:client) { Invoca::Metrics::Client.new('localhost', '5678', 'test_cluster', 'test_service', 'test_label', 'sub_server') }
    let(:cache) { double(described_class) }

    describe '#register' do
      it 'initializes a new GaugeCache object for the client' do
        expect(described_class).to receive(:new).and_return(cache)
        expect(described_class.register(client.gauge_cache_key, statsd)).to eq(cache)
      end
    end
  end

  describe 'initialize' do
    it 'kicks off a new thread for reporting the cached gauges' do
      expect_any_instance_of(described_class).to receive(:report)
      expect_any_instance_of(described_class).to receive(:sleep).with(any_args)
      expect_any_instance_of(described_class).to receive(:loop) { |&loop_block| loop_block.call }
      expect(Thread).to receive(:new) { |&thread_block| thread_block.call }

      described_class.new(statsd)
    end
  end

  describe 'instance' do
    let(:metric) { 'test.gauge.metric' }
    let(:value)  { 1 }

    subject { described_class.new(statsd) }

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
          expect(statsd).to receive(:batch).and_yield(statsd)
          expect(statsd).to_not receive(:gauge)
          subject.report
        end
      end

      describe 'with gauges currently set' do
        it 'reports all gauges currently set as gauges on the statsd instance' do
          expect(statsd).to receive(:batch).and_yield(statsd)
          gauges.each { |metric, value| expect(statsd).to receive(:gauge).with(metric, value) }
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
          expect(statsd).to receive(:batch).and_yield(statsd)
          gauges.each do |metric, value|
            if value.nil?
              expect(statsd).to receive(:gauge).with(metric, value).never
            else
              expect(statsd).to receive(:gauge).with(metric, value)
            end
          end
          subject.report
        end
      end
    end
  end
end
