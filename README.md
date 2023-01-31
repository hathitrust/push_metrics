# `push_metrics`

[![Tests](https://github.com/hathitrust/push_metrics/actions/workflows/tests.yml/badge.svg)](https://github.com/hathitrust/push_metrics/actions/workflows/tests.yml)

A gem for pushing metrics on progress and completion of batch jobs to a
[Prometheus Pushgateway](https://github.com/prometheus/pushgateway). Uses the
[milemarker](github.com/hathitrust/milemarker) interface for callbacks to
report progress.

## Dependencies

* `ruby` > 2.7
* [Prometheus Pushgateway](https://github.com/prometheus/pushgateway)

## Installation

In your `Gemfile`:

`gem 'push_metrics', git: 'https://github.com/hathitrust/push_metrics'`

## Usage

Basic usage is the same as `milemarker`, but progress will be reported to the
push gateway after each `batch_size` records and on completion.

```ruby
require 'push_metrics';

marker = PushMetrics.new(batch_size: 1000)

File.open(input_file).each do |line|
  do_whatever_needs_doing(line)
  marker.increment_and_log_batch_line
end

marker.log_final_line 
```

### Options

You can configure the job name and expected success interval as used
in reporting to the pushgateway:

```ruby
PushMetrics.new(job_name: 'my_job_name')
```

* `job_name` defaults to the name of the originally-invoked script
  (`basename($PROGRAM_NAME)` / `basename($0)`)

* `success_interval` defaults to the value of the
  `JOB_SUCCESS_INTERVAL` environment variable

### Push Gateway

To configure the pushgateway endpoint, you can either pass the
endpoint for the push gateway:

```ruby
PushMetrics.new(pushgateway_endpoint: "http://pushgateway:9091")
```

or set the `PUSHGATEWAY` environment variable.

### Prometheus

By default, PushMetrics uses the default `Prometheus::Client.registry`. If you
are using Prometheus for other purposes or wish to set other metrics, you can
pass in your own registry, or add your metrics to the default
`Promtheus::Client.registry`. PushMetrics will push those additional metrics
along with its defaults.

### Configuring `milemarker`

PushMetrics is a subclass of Milemarker, so you can pass in constructor
arguments for Milemarker as well:

```ruby
pushmetrics = PushMetrics.new(logger: my_custom_logger)
```

### Using another Milemarker implementation

If you want to use a different Milemarker (e.g. Milemarker::Structured), you can do that:

```ruby
pushmetrics = PushMetrics(Milemarker::Structured).new
```

🤯 thanks to the magic of dynamic class definition in Ruby...

See also [milemarker](https://github.com/hathitrust/milemarker) for additional options and configuration.

### Environment Variables

* `PUSHGATEWAY`: Endpoint for the pushgateway; defaults to
  `http://localhost:9091`

* `JOB_EXPECTED_SUCCESS_INTERVAL`: If set, used to populate the
  `job_expected_success_interval` metric.

### Prometheus Metrics

* `job_duration_seconds`
* `job_last_success`
* `job_records_processed`
* `job_expected_success_interval`: Set from the `JOB_SUCCESS_INTERVAL`
  environment variable or `success_interval` constructor parameter.  Set to the
maximum expected interval in seconds between successes of the job. For example,
if the job runs once a day, set this to 86400 (the number of seconds in a day)
plus some extra amount of "slop" to account for normal variation of how long
the job might take to run. This metric can be used to set a generic alert in
prometheus when jobs do not complete in the expected time frame:

```yaml
- alert: JobCompletionTimeoutExceeded
  expr: "time() - job_last_success > job_expected_success_interval"
  for: 0m
  labels:
    severity: warning
  annotations:
     summary: "Job {{$labels.job}} has not completed successfully"
     description: "Job {{$labels.job}} has not completed successfully\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}"
```

## Contributing

```bash
git clone https://github.com/hathitrust/push_metrics
cd push_metrics
bundle install
```

The repository comes with support for starting a local push gateway for use in the integration tests. 

> :warning: Do not run the tests against a pushgateway with data you care
> about! The tests require the pushgateway to be started with the
> `--web.enable-admin-api` flag, and use the `/api/v1/admin/wipe` endpoint to
> **remove all data** from the pushgateway between tests.

```bash
docker-compose up -d
bundle exec rspec
```

Bug reports and pull requests are welcome on GitHub at https://github.com/hathitrust/push_metrics.

## License

The gem is available as open source under the terms of the [BSD3 License](https://opensource.org/licenses/BSD-3-Clause).
