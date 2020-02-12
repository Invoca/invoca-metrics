# frozen_string_literal: true

describe Invoca::Metrics::GaugeCache do
  let(:client) { Invoca::Metrics::Client.new('localhost', '5678', 'test_cluster', 'test_service', 'test_label', 'sub_server') }

  after(:each) { described_class.reset }

  describe 'class' do
    let(:cache) { double(described_class) }

    describe '#[]' do
      describe 'when passed a new client' do
        it 'creates and returns a new instance of GaugeCache' do
          expect(described_class).to receive(:new).with(client).and_return(cache)
          expect(described_class[client]).to eq(cache)
        end
      end

      describe 'when passed a previously used client' do
        it 'returns the same GaugeCache previously returned' do
          expect(described_class).to receive(:new).with(client).and_return(cache).exactly(1)
          expect(described_class[client]).to eq(cache)
          expect(described_class[client]).to eq(cache)
        end
      end
    end

    describe '#start_report_thread' do
      describe 'when passed a new client' do
        let(:thread) { double(Thread) }

        it 'spins off a new thread for reporting the set gauges for that client' do
          expect(Thread).to receive(:new).and_return(thread)
          expect(described_class.start_report_thread(client)).to eq(thread)
        end
      end

      describe 'when passed a previously used client' do
        before(:each) do
          described_class.start_report_thread(client)
        end

        it 'does nothing' do
          expect(Thread).to_not receive(:new)
          expect(described_class.start_report_thread(client)).to be_a(Thread)
        end
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
          expect(proc).to receive(:bind).with(client).and_return(proc)
          gauges.each { |metric, value| expect(proc).to receive(:call).with(metric, value) }
          subject.report
        end
      end
    end
  end
end
