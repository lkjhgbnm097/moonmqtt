# Contributing to MoonMQTT

Contributions are welcome. Protocol changes should start with an issue that
links the relevant MQTT 5.0 section and describes observable wire behavior.

## Development checks

```bash
moon update
moon fmt --check
moon check --target wasm --deny-warn
moon test --target wasm
moon check --target native --deny-warn
moon test --target native
moon info
```

When Mosquitto is available locally:

```bash
moon run --target native integration/mosquitto
```

## Change requirements

- Keep protocol and platform I/O separated.
- Add a test for every bug fix and every new protocol branch.
- Use normative MQTT 5.0 terminology in public APIs and documentation.
- Do not silently accept malformed packets to improve compatibility.
- Preserve unknown business payloads as bytes.
- Update `docs/PROTOCOL_SUPPORT.md` and `CHANGELOG.md` for visible features.
- Run `moon info && moon fmt` before submitting a pull request.

## Commit guidance

Prefer small, reviewable commits such as `codec: validate topic alias` or
`native: add TLS trust configuration`. Do not split generated or mechanical
changes into artificial commits.

By contributing, you agree that your contribution is licensed under Apache-2.0.
