# Invoca::Metrics

Metrics generation for your apps!

## Installation

Add this line to your application's Gemfile:

    gem 'invoca-metrics'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install invoca-metrics

## Setup

### Default Setup

Add the following code to your application...

    require 'invoca/metrics'

    Invoca::Metrics.service_name    = "my_event_worker"
    Invoca::Metrics.server_name     = Socket.gethostname
    Invoca::Metrics.cluster_name    = "production"
    Invoca::Metrics.sub_server_name = "worker_process_1"
    Invoca::Metrics.statsd_host     = "255.0.0.123"
    Invoca::Metrics.statsd_port     = 200

Out of the settings above, only `service_name` is required.  The others are optional.

### Multi Configuration

In order to configure multiple configurations, supply a `config` hash with additional settings.

    Invoca::Metrics.config = {
      deployment_group: {
        server_name: "deployment"
        statsd_host: "255.0.0.456",
        statsd_port: 300
      },
      region: {
        server_name:     "region_name"
        statsd_host:     "255.0.0.789",
        statsd_port:     400,
        sub_server_name: nil
        cluster_name:    nil
      }
    }

The settings (`[service_name, server_name, cluster_name, sub_server_name, statsd_host, statsd_port]`) directly set on `Invoca::Metrics` will be the default values supplied if the individual configuration does not supply the option.
It's highly suggested that each configuration has its own `statsd_host` and `statsd_port` along with unique naming since writing the same metric from one statsd node could be overwritten by the same metric from a separate node.

In order to set a configuration as the default, set the configuration key as `default_config_key`.

    Invoca::Metrics.default_config_key = :deployment_group

Any keys missing from the `default_config_key` config will by default have the values from the keys set directly on `Invoca::Metrics`.

The full set of default values for the above example would then be

    service_name:    "my_event_worker"
    cluster_name:    "production"
    sub_server_name: "worker_process_1"
    server_name:     "deployment"
    statsd_host:     "255.0.0.456",
    statsd_port:     300


## Usage

Mixin the Source module:

    class MyClass
      include Invoca::Metrics::Source
      ...
    end

Then call any method from `Invoca::Metrics::Client` via the `metrics` member (the client will be configured with the default config):

    metrics.timer("some_process/execution_time", time_in_ms)

You can also request a specific configuration by calling `metrics_for(config_key: configuration_key)`

    metrics_for(config_key: :region).count("region_upload.success")

Additional examples of using the gem can be found in the file: test/integration/metrics_gem_tester.rb

## TODO

* it would be really nice to remove the dependency on the activesupport gem

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
