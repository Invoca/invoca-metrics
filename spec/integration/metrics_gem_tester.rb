# frozen_string_literal: true

class MetricsGemTester
  include Invoca::Metrics::Source

  def fire_direct_metrics
    puts "about to fire"
    direct_metric(1.0, 5.0)
    sleep(10)
    direct_metric(2.0, 10.0)
    sleep(10)
    direct_metric(20.0, 3.0)
    puts "firing done"
  end

  def fire_statsd_metrics
    metrics.timer("metricgemreport/sampletime", 300)
    puts "Timer metric fired"
    metrics.gauge("metricgemreport/samplegauge", 10)
    puts "Gauge metric fired"
    metrics.counter("metricgemreport/samplecounter", 5)
    puts "Counter metric fired"
    metrics.increment("metricgemreport/sampleinc")
    puts "Increment metric fired"
    metrics.decrement("metricgemreport/sampledec")
    puts "Decrement metric fired"
    metrics.set("metricgemreport/sampleset", 100)
    puts "Set metric fired"
  end

  def direct_metric(count_value, median_value)
    m1 = Invoca::Metrics::DirectMetric.new("metricgemreport..couldbeanything.duration_in_seconds.count", count_value)
    m2 = Invoca::Metrics::DirectMetric.new("metricgemreport.couldbeanything.duration_in_seconds.median", median_value)
    Invoca::Metrics::DirectMetric.report([m1, m2])
    puts "fired pair of direct metrics with count=#{count_value} and median=#{median_value}"
  end
end
