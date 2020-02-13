# frozen_string_literal: true

require 'sourcify'

describe Invoca::Metrics::GaugeCache do
  let(:client) { Invoca::Metrics::Client.new('localhost', '5678', 'test_cluster', 'test_service', 'test_label', 'sub_server') }

  describe 'class' do
    let(:cache) { double(described_class) }

    describe '#register' do
      it 'initializes a new GaugeCache object for the client' do
        expect(described_class).to receive(:new).with(client).and_return(cache)
        expect(Thread).to receive(:new)
        expect(described_class.register(client)).to eq(cache)
      end

      it 'kicks off a new thread for reporting the cached gauges' do
        expect(described_class).to receive(:new).with(client).and_return(cache)
        expect(Thread).to receive(:new) do |&block|
          expect(block.to_source.chomp).to eq(<<~EOS.chomp)
            proc do
              gauge_cache.report
              sleep(GAUGE_REPORT_INTERVAL)
            end
          EOS
        end
        expect(described_class.register(client)).to eq(cache)
      end
    end
  end

  describe 'instance' do
    let(:metric) { 'test.gauge.metric' }
    let(:value)  { 1 }

    subject { described_class.new(client) }

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

        it 'should remove the metric from the cache' do
          subject.set(metric, value)
          expect(subject.cache).to_not include(metric)
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
          expect(client).to_not receive(:gauge)
          subject.report
        end
      end

      describe 'with gauges currently set' do
        let(:proc) { double(Proc) }

        it 'reports all gauges currently set as counts' do
          expect(::Statsd).to receive(:instance_method).with(:gauge).and_return(proc)
          expect(proc).to receive(:bind).with(instance_of(Invoca::Metrics::Batch)).and_return(proc)
          gauges.each { |metric, value| expect(proc).to receive(:call).with(metric, value) }
          subject.report
        end
      end
    end
  end
end
