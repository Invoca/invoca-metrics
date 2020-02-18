# frozen_string_literal: true

require 'sourcify'

describe Invoca::Metrics::GaugeCache do
  let(:client) { Invoca::Metrics::Client.new('localhost', '5678', 'test_cluster', 'test_service', 'test_label', 'sub_server') }

  describe 'class' do
    let(:cache) { double(described_class) }

    describe '#register' do
      before(:each) do
        expect(described_class).to receive(:new).and_return(cache)
      end

      it 'initializes a new GaugeCache object for the client' do
        expect(Thread).to receive(:new)
        expect(described_class.register(client)).to eq(cache)
      end

      it 'kicks off a new thread for reporting the cached gauges' do
        expect(Thread).to receive(:new) do |&block|
          expect(block.to_source.chomp).to eq(<<~EOS.chomp)
            proc do
              next_time = Time.now.to_i
              loop do
                next_time = (((next_time + GAUGE_REPORT_INTERVAL_SECONDS) / GAUGE_REPORT_INTERVAL_SECONDS) * GAUGE_REPORT_INTERVAL_SECONDS)
                gauge_cache.report
                sleep((next_time - Time.now.to_i))
              end
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

        it 'should set the metric value to nil' do
          subject.set(metric, value)
          expect(subject.cache).to eq(metric => value)
        end
      end
    end

    describe '#report' do
      let(:proc) { double(Proc) }
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
          expect(client).to_not receive(:gauge_without_caching)
          subject.report
        end
      end

      describe 'with gauges currently set' do
        it 'reports all gauges currently set as counts' do
          expect(client).to receive(:batch).and_yield(proc)
          gauges.each { |metric, value| expect(proc).to receive(:gauge_without_caching).with(metric, value) }
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
          expect(client).to receive(:batch).and_yield(proc)
          gauges.each do |metric, value|
            if value.nil?
              expect(proc).to receive(:gauge_without_caching).with(metric, value).never
            else
              expect(proc).to receive(:gauge_without_caching).with(metric, value)
            end
          end
          subject.report
        end
      end
    end
  end
end
