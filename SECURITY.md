# Security Policy

## Supported versions

MoonMQTT has not made its first stable release. Security fixes are applied to
the latest development branch only.

## Reporting a vulnerability

Do not open a public issue for vulnerabilities involving packet parsing,
resource exhaustion, TLS verification, authentication data, or credential
exposure. Before the first public release, enable GitHub private vulnerability
reporting and use that channel for security reports.

Include:

- affected commit or version;
- minimal reproduction or packet bytes;
- expected and actual behavior;
- impact and whether the issue is remotely triggerable.

## Security boundaries

- `--insecure` disables certificate verification and is for local testing only.
- Password and authentication data are represented as bytes and must not be
  emitted in application logs.
- Packet size limits should be enforced by applications until negotiated
  Maximum Packet Size handling is added to `NativeClient`.
- The project has not completed an external audit or MQTT conformance
  certification.
