# Changelog

## Unreleased

### Added

- Added `PublishContract` and deterministic release-gate APIs for topic,
  payload-size, QoS, Retain, Content Type, User Property, expiry, response-topic,
  and correlation-data enforcement.
- Added stable, machine-readable denial reasons that report every violation in
  one decision.
- Added a runnable `examples/release_gate` governance demonstration.
- Added a public differentiation audit covering the existing MoonBit MQTT
  codec, client, and broker projects.

### Changed

- Repositioned the project as **MoonMQTT Guard**, an MQTT 5 message-contract
  and publish-governance layer. The native client remains a reference adapter,
  not the project's primary product claim.

All notable changes to MoonMQTT will be documented in this file. The project
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and intends to
use semantic versioning after the first public release.

## [Unreleased]

### Added

- MQTT 5.0 packet model for all control packet types.
- Strict encoder, decoder, property validation, and streaming decoder.
- MQTT UTF-8 and hexadecimal utilities.
- Deterministic QoS 0/1/2 client session state machine.
- Native TCP/TLS client based on `moonbitlang/async`.
- Packet inspector, publisher, and subscriber CLI commands.
- Portable, native, mock-broker, and Mosquitto integration tests.
- Architecture, protocol support, proposal, roadmap, and demo documentation.
- MQTT topic-filter matching with shared-subscription and `$SYS` semantics.
- Configurable streaming packet-size limits.
- Broker-negotiated Receive Maximum and Maximum Packet Size enforcement.
- Persistent-session resume driven by Clean Start and Session Present.
- Deterministic reconnect backoff and keep-alive scheduling primitives.
- A bounded offline publish queue with reject and drop-oldest policies.
