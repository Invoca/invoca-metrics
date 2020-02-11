# frozen_string_literal: true

describe Invoca::Metrics::GaugeCache do
  describe 'instance' do
    let(:client) { double(Invoca::Metrics::Client) }
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
          expect(client).to_not receive(:count)
          subject.report
        end
      end

      describe 'with gauges currently set' do
        it 'reports all gauges currently set as counts' do
          gauges.each { |metric, value| expect(client).to receive(:count).with(metric, value) }
          subject.report
        end
      end
    end
  end
end
