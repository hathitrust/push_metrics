# frozen_string_literal: true

require "push_metrics"
require "climate_control"
require "faraday"

# stub a method that counts the number of times it is called, and returns that
# via a _calls method, e.g. count_calls(whatever) will create a #whatever
# method and a #whatever_calls method that returns the time #whatever was
# called.

def count_calls(name, rval = nil)
  define_method(name) do
    calls = instance_variable_get(:"@#{name}_calls")
    calls ||= 0
    calls += 1
    instance_variable_set(:"@#{name}_calls", calls)
    rval
  end

  define_method(:"#{name}_calls") do
    instance_variable_get(:"@#{name}_calls")
  end
end

class StubMarker
  attr_accessor :stub_seconds_so_far, :stub_records_so_far, :incr_calls

  def initialize(stub_records_so_far:,
    stub_seconds_so_far:,
    **kwargs)
    @stub_records_so_far = stub_records_so_far
    @stub_seconds_so_far = stub_seconds_so_far
  end

  def final_line
    true
  end

  def total_seconds_so_far
    @stub_seconds_so_far
  end

  def count
    @stub_records_so_far
  end

  def on_batch
    yield self
  end

  count_calls :incr
  count_calls :on_batch
  count_calls :final_line, "final line"
end

RSpec.describe PushMetrics do
  let(:batch_size) { rand(1..100) }
  let(:seconds_so_far) { rand(100) }
  let(:records_so_far) { rand(100) }
  let(:success_interval) { 24 * 60 * 60 * rand(7) }

  describe "unit tests" do
    let(:pushgateway) { instance_double(Prometheus::Client::Push, add: true) }
    let(:metrics) { Prometheus::Client::Registry.new }
    let(:marker) { StubMarker }

    let(:params) do
      {
        batch_size: batch_size,
        pushgateway: pushgateway,
        registry: metrics,
        stub_seconds_so_far: seconds_so_far,
        stub_records_so_far: records_so_far
      }
    end

    let(:pm_marker) do
      PushMetrics(marker).new(**params)
    end

    describe "#initialize" do
      it "can be constructed" do
        expect(pm_marker).not_to be(nil)
      end

      it "sets initial values for duration and records processed" do
        pm_marker

        expect(metrics.get(:job_duration_seconds).get).to eq(seconds_so_far)
        expect(metrics.get(:job_records_processed).get).to eq(records_so_far)
      end

      it "doesn't set last success" do
        pm_marker

        expect(metrics.get(:job_last_success)).to be(nil)
      end

      it "by default doesn't set success interval" do
        pm_marker

        expect(metrics.get(:job_expected_success_interval)).to be(nil)
      end

      it "sets success interval metric with constructor param" do
        PushMetrics(marker).new(**params.merge({success_interval: success_interval}))

        expect(metrics.get(:job_expected_success_interval).get).to eq(success_interval)
      end

      it "pushes initial metrics to pushgateway" do
        expect(pushgateway).to receive(:add).with(metrics)

        pm_marker
      end
    end

    describe "#incr" do
      it "calls superclass method" do
        pm_marker.incr
        expect(pm_marker.incr_calls).to be 1
      end
    end

    describe "#final_line" do
      it "calls superclass method" do
        pm_marker.final_line
        expect(pm_marker.final_line_calls).to be 1
      end

      it "returns what superclass returns" do
        expect(pm_marker.final_line).to eq("final line")
      end

      it "updates the metrics" do
        pm_marker.final_line

        expect(metrics.get(:job_duration_seconds).get).to eq(seconds_so_far)
        expect(metrics.get(:job_records_processed).get).to eq(records_so_far)
        expect(metrics.get(:job_last_success).get).to eq(Time.now.to_i)
      end

      it "pushes metrics to pushgateway" do
        expect(pushgateway).to receive(:add).with(metrics)

        pm_marker.final_line
      end
    end

    describe "#on_batch" do
      it "calls superclass method" do
        pm_marker.on_batch {}
        expect(pm_marker.on_batch_calls).to be 1
      end

      it "updates the metrics" do
        pm_marker.on_batch {}

        expect(metrics.get(:job_duration_seconds).get).to eq(seconds_so_far)
        expect(metrics.get(:job_records_processed).get).to eq(records_so_far)
      end

      it "pushes metrics to pushgateway" do
        expect(pushgateway).to receive(:add).with(metrics)

        pm_marker.on_batch {}
      end

      it "doesn't overwrite last success metric" do
        pm_marker.on_batch {}

        expect(metrics.get(:job_last_success)).to be(nil)
      end
    end
  end

  describe "integration test" do
    before(:each) do
      Faraday.put("#{pm_endpoint}/api/v1/admin/wipe")
    end

    let(:pm_endpoint) { ENV["PUSHGATEWAY"] || "http://localhost:9091" }
    let(:metrics) { Faraday.get("#{pm_endpoint}/metrics").body }
    let(:pm_marker) { PushMetrics.new(batch_size: batch_size, registry: Prometheus::Client::Registry.new) }

    describe "#on_batch" do
      before(:each) do
        pm_marker.incr(batch_size)
        pm_marker.on_batch {}
      end

      it "updates job_duration_seconds" do
        expect(metrics).to match(/^job_duration_seconds\S* [\d.]+$/m)
      end

      it "updates job_records_processed" do
        expect(metrics).to match(/^job_records_processed\S* \d+$/m)
      end

      it "does not update job_last_success" do
        expect(metrics).not_to match(/^job_last_success/m)
      end

      it "by default does not update job_expected_success_interval" do
        expect(metrics).not_to match(/^job_expected_success_interval/m)
      end
    end

    describe "instance label" do
      it "has an empty instance label by default" do
        pm_marker.on_batch {}
        expect(metrics).to match(/^job_duration_seconds.*instance=""/m)
      end

      it "uses instance param if given" do
        ClimateControl.modify(JOB_NAMESPACE: "some-namespace") do
          pm = PushMetrics.new(batch_size: batch_size, registry: Prometheus::Client::Registry.new, instance: "override-instance")
          pm.on_batch {}
          expect(metrics).to match(/^job_duration_seconds.*instance="override-instance"/m)
        end
      end

      it "uses JOB_NAMESPACE env var as instance if given" do
        ClimateControl.modify(JOB_NAMESPACE: "some-namespace") do
          pm_marker.on_batch {}
          expect(metrics).to match(/^job_duration_seconds.*instance="some-namespace"/m)
        end
      end
    end

    it "can record success" do
      pm_marker.final_line
      # job_last_success is nonzero
      expect(metrics).to match(/^job_last_success\S* \S+/m)
    end
  end

  describe "error handling" do
    let(:pm_endpoint) { "http://pushgateway.invalid:9091" }

    context "with a logger" do
      let(:logger) { instance_double Logger, error: nil }
      let(:pm_marker) {
        PushMetrics.new(batch_size: batch_size, registry: Prometheus::Client::Registry.new,
          pushgateway_endpoint: pm_endpoint, logger: logger)
      }

      it "logs exception" do
        expect(logger).to receive(:error)
        pm_marker
      end
    end

    context "without a logger" do
      let(:pm_marker) {
        PushMetrics.new(batch_size: batch_size, registry: Prometheus::Client::Registry.new,
          pushgateway_endpoint: pm_endpoint)
      }

      it "does not raise error" do
        expect { pm_marker }.not_to raise_error
      end
    end
  end
end

RSpec.describe "PushMetric varieties" do
  it "can subclass Milemarker::Structured" do
    expect(PushMetrics(Milemarker::Structured).new).to be_a(Milemarker::Structured)
  end
end
