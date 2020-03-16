# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.6.1] - 2020-03-16
### Added
- `metrics_namespace` decorator for setting the namespace for globally for a module or class that includes `Invoca::Metrics::Source`
- `Invoca::Metrics::StatsdClient` for housing improvements to the `Statsd` class
- Changelog based on formatting provided by [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

### Removed
- Removed Rails as a dependency of Gem

### Changed
- Refactored `Invoca::Metrics::Client` to use composition instead of inheritance to avoid global mutation bugs

### Fixed
- A bug in namespace reassignment of the `Client` that was allowing global mutation of the metrics namespace

## [1.6.0] - 2020-03-02
### Added
- `Invoca::Metrics::GaugeCache` for keeping track of gauges set within memory
- Internal caching within `Invoca::Metrics::Client` based on configuration

## [1.0.0] - 2014-07-23
Initial release
<!-- TODO: Backfill the contents of the initial release -->


[Unreleased]: https://github.com/Invoca/invoca-metrics/compare/v1.6.1...HEAD
[1.6.1]: https://github.com/Invoca/invoca-metrics/compare/v1.6.0...v1.6.1
[1.6.0]: https://github.com/Invoca/invoca-metrics/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/Invoca/invoca-metrics/compare/v1.0.5...v1.5.0
[1.0.5]: https://github.com/Invoca/invoca-metrics/compare/v1.0.4...v1.0.5
[1.0.4]: https://github.com/Invoca/invoca-metrics/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/Invoca/invoca-metrics/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/Invoca/invoca-metrics/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/Invoca/invoca-metrics/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/Invoca/invoca-metrics/releases/tag/v1.0.0
