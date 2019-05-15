# frozen_string_literal: true

require_relative '../../../test_helper'
require_relative '../../../helpers/metrics/metrics_test_helpers'

describe Invoca::Metrics::Batch do
  include MetricsTestHelpers

  context "batching" do
    setup do
      stub_metrics_as_production_unicorn
      @metrics_client = Invoca::Metrics::Client.metrics
      @metrics_client.extend TrackSentMessage
    end

    should "batch multiple stats in one message" do
      @metrics_client.batch do |stats_batch|
        stats_batch.counter("test_runs", 1)
        stats_batch.gauge("current_size", 9)
        stats_batch.gauge("memory", 128000)
      end
      stats_lines = @metrics_client.sent_message.split("\n")
      assert_equal %w( unicorn.test_runs.counter.prod-fe1:1|c
                       unicorn.current_size.gauge.prod-fe1:9|g
                       unicorn.memory.gauge.prod-fe1:128000|g ), stats_lines
    end

    should "batch multiple stats in one message, sent in batches" do
      @metrics_client.batch do |stats_batch|
        stats_batch.batch_size = 2
        stats_batch.counter("test_runs", 1)
        stats_batch.gauge("current_size", 9)
        stats_batch.gauge("memory", 128000)
      end
      stats_lines = @metrics_client.sent_messages.map { |msg| msg.split("\n") }
      assert_equal [ %w(unicorn.test_runs.counter.prod-fe1:1|c
                    unicorn.current_size.gauge.prod-fe1:9|g),
                    %w(unicorn.memory.gauge.prod-fe1:128000|g)], stats_lines
    end

    should "send nothing if batch is empty" do
      metrics_client = Invoca::Metrics::Client.metrics
      metrics_client.extend TrackSentMessage

      metrics_client.batch { |stats_batch| }

      assert_nil metrics_client.sent_message
    end
  end
end
