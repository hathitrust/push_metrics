# frozen_string_literal: true

require "milemarker"
require "delegate"

# Adds prometheus push exporter to Milemarker that tracks:
#   - number of items processed
#   - time running so far
#   - success time
class PushMetrics < SimpleDelegator
  def initialize(batch_size,
    marker: Milemarker.new(batch_size: batch_size),
    registry: Prometheus::Client.registry,
    job_name: File.basename($PROGRAM_NAME),
    pushgateway_endpoint: ENV["PUSHGATEWAY"],
    success_interval: ENV["JOB_SUCCESS_INTERVAL"],
    pushgateway: Prometheus::Client::Push.new(job: job_name, gateway: pushgateway_endpoint))

    @marker = marker
    @pushgateway = pushgateway
    @registry = registry

    super(@marker)

    if success_interval
      success_interval_metric.set(success_interval.to_i)
    end

    update_metrics
  end

  def final_line
    last_success_metric.set(Time.now.to_i)
    update_metrics
    marker.final_line
  end

  def on_batch
    marker.on_batch do |m|
      yield m
      update_metrics
    end
  end

  private

  attr_reader :marker, :pushgateway, :registry, :metrics

  def update_metrics
    duration_metric.set(@marker.total_seconds_so_far)
    records_processed_metric.set(@marker.count)

    pushgateway.add(registry)
  end

  def duration_metric
    @duration_metric ||= register_metric(:job_duration_seconds, docstring: "Time spent running job in seconds")
  end

  def last_success_metric
    @last_success_metric ||= register_metric(:job_last_success, docstring: "Last Unix time when job successfully completed")
  end

  def records_processed_metric
    @records_processed ||= register_metric(:job_records_processed, docstring: "Records processed by job")
  end

  def success_interval_metric
    @success_interval ||= register_metric(:job_expected_success_interval, docstring: "Maximum expected time in seconds between job completions")
  end

  def register_metric(name, **kwargs)
    registry.get(name) ||
      Prometheus::Client::Gauge.new(name, **kwargs).tap { |m| registry.register(m) }
  end
end
