# frozen_string_literal: true

require "milemarker"
require "prometheus/client/push"

# Adds prometheus push exporter to Milemarker or similar interface that tracks:
#   - number of items processed
#   - time running so far
#   - success time
#
# This is a bit unusual syntax, but it allows us to have:
#   * PushMetrics is a regular class that inherits from Milemarker, just in a
#     bit of an unusual way
#
#   * PushMetrics(SomeOtherClass) is a new anonymous class that inherits from
#     SomeOtherClass - so we can use another Milemarker implementation, including
#     a stubbed one, while still being able to use the callbacks here as
#     overrides to the methods in SomeOtherClass.

def PushMetrics(superclass)
  Class.new(superclass) do
    def initialize(
      registry: Prometheus::Client.registry,
      job_name: File.basename($PROGRAM_NAME),
      pushgateway_endpoint: ENV["PUSHGATEWAY"] || "http://localhost:9091",
      success_interval: ENV["JOB_SUCCESS_INTERVAL"],
      pushgateway: Prometheus::Client::Push.new(job: job_name, gateway: pushgateway_endpoint),
      **kwargs
    )

      super(**kwargs)

      @pushgateway = pushgateway
      @registry = registry

      if success_interval
        success_interval_metric.set(success_interval.to_i)
      end

      update_metrics
    end

    def final_line
      last_success_metric.set(Time.now.to_i)
      update_metrics
      super
    end

    def on_batch
      super do |m|
        yield m
        update_metrics
      end
    end

    private

    attr_reader :pushgateway, :registry, :metrics

    def update_metrics
      duration_metric.set(total_seconds_so_far)
      records_processed_metric.set(count)

      begin
        pushgateway.add(registry)
      rescue => e
        logger&.error(e.to_s)
      end
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
end

# Constants (including classes) are in a different namespace from functions, so
# we can make a PushMetrics class whose superclass is Milemarker be the
# "default" PushMetrics class.

PushMetrics = PushMetrics(Milemarker)
