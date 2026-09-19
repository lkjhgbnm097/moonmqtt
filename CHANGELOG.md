# Changelog

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
