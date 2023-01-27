# frozen_string_literal: true

require "push_metrics"
require "faraday"

RSpec.describe PushMetrics do
  let(:batch_size) { rand(1..100) }
  let(:seconds_so_far) { rand(100) }
  let(:records_so_far) { rand(100) }
  let(:success_interval) { 24 * 60 * 60 * rand(7) }

  describe "unit tests" do
    let(:marker) do
      instance_double(Milemarker,
        final_line: true,
        total_seconds_so_far: seconds_so_far,
        count: records_so_far).tap do |d|
        allow(d).to receive(:on_batch).and_yield(d)
      end
    end

    let(:pushgateway) { instance_double(Prometheus::Client::Push, add: true) }
    let(:metrics) { Prometheus::Client::Registry.new }

    let(:params) do
      {
        marker: marker,
        pushgateway: pushgateway,
        registry: metrics
      }
    end

    let(:pm_marker) do
      described_class.new(batch_size, **params)
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
        described_class.new(batch_size, **params.merge({success_interval: success_interval}))

        expect(metrics.get(:job_expected_success_interval).get).to eq(success_interval)
      end

      it "pushes initial metrics to pushgateway" do
        expect(pushgateway).to receive(:add).with(metrics)

        pm_marker
      end
    end

    describe "#incr" do
      it "delegates to marker" do
        expect(marker).to receive(:incr)
        pm_marker.incr
      end
    end

    describe "#final_line" do
      it "delegates to milemarker" do
        expect(marker).to receive(:final_line)

        pm_marker.final_line
      end

      it "returns what milemarker returns" do
        allow(marker).to receive(:final_line).and_return("milemarker return")

        expect(pm_marker.final_line).to eq("milemarker return")
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
      it "delegates to marker" do
        expect(marker).to receive(:on_batch)

        pm_marker.on_batch {}
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

    describe "#count" do
      it "delegates to marker" do
        expect(marker).to receive(:count)
        pm_marker.count
      end
    end
  end

  describe "integration test" do
    before(:each) do
      Faraday.put("#{pm_endpoint}/api/v1/admin/wipe")
    end

    let(:pm_endpoint) { ENV["PUSHGATEWAY"] || "http://localhost:9091" }
    let(:metrics) { Faraday.get("#{pm_endpoint}/metrics").body }
    let(:pm_marker) { described_class.new(batch_size, registry: Prometheus::Client::Registry.new) }

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

    it "can record success" do
      pm_marker.final_line
      # job_last_success is nonzero
      expect(metrics).to match(/^job_last_success\S* \S+/m)
    end
  end
end
