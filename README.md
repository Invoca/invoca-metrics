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

Add the following code to your application...

    require 'invoca/metrics'

    Invoca::Metrics.service_name    = "my_event_worker"
    Invoca::Metrics.server_name     = Socket.gethostname
    Invoca::Metrics.cluster_name    = "production"
    Invoca::Metrics.sub_server_name = "worker_process_1"

Out of the four settings above, only `service_name` is required.  The others are optional.

### server_name vs server_group

The default `:server_identifier` is `:server_name`. Set `server_identifier` as `:server_group` in order to defer to using a more generic label than the supplied `server_name`

Note: `sub_server_name` and `cluster_name` are not affected

    Invoca::Metrics.server_group             = "my_group"
    Invoca::Metrics.server_identifier        = :server_group
    Invoca::Metrics.server_group_statsd_host = "127.0.0.1"
    Invoca::Metrics.server_group_statsd_port = 1

## Usage

Mixin the Source module:

    class MyClass
      include Invoca::Metrics::Source
      ...
    end

Then call any method from `Invoca::Metrics::Client` via the `metrics` member:

    metrics.timer("some_process/execution_time", time_in_ms)

Additional examples of using the gem can be found in the file: test/integration/metrics_gem_tester.rb

## TODO

* it would be really nice to remove the dependency on the activesupport gem

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
