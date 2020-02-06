# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Invoca::Metrics::Batch do
  let(:metrics_client) { Invoca::Metrics::Client.metrics }

  before(:each) do
    stub_metrics_as_production_unicorn
    metrics_client.extend(TrackSentMessage)
  end

  it "batch multiple stats in one message" do
    expected = [
      "unicorn.test_runs.counter.prod-fe1:1|c",
      "unicorn.current_size.gauge.prod-fe1:9|g",
      "unicorn.memory.gauge.prod-fe1:128000|g"
    ]

    metrics_client.batch do |stats_batch|
      stats_batch.counter("test_runs", 1)
      stats_batch.gauge("current_size", 9)
      stats_batch.gauge("memory", 128000)
    end

    stats_lines = metrics_client.sent_message.split("\n")
    expect(stats_lines).to eq(expected)
  end

  it "batch multiple stats in one message, sent in batches" do
    expected = [
      [
        "unicorn.test_runs.counter.prod-fe1:1|c",
        "unicorn.current_size.gauge.prod-fe1:9|g"
      ],
      [
        "unicorn.memory.gauge.prod-fe1:128000|g"
      ]
    ]

    metrics_client.batch do |stats_batch|
      stats_batch.batch_size = 2
      stats_batch.counter("test_runs", 1)
      stats_batch.gauge("current_size", 9)
      stats_batch.gauge("memory", 128000)
    end

    stats_lines = metrics_client.sent_messages.map { |msg| msg.split("\n") }
    expect(stats_lines).to eq(expected)
  end

  it "send nothing if batch is empty" do
    metrics_client.batch { }
    expect(metrics_client.sent_message).to be_nil
  end
end
