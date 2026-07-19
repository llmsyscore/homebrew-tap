# llmsyscore Homebrew tap

Formulae for [LLM Systems Manager](https://github.com/llmsyscore/llm-systems-manager) —
macOS (Apple Silicon) and Linux (x86_64; arm64 best-effort).

    brew tap llmsyscore/tap
    brew trust llmsyscore/tap   # newer Homebrew requires trusting third-party taps

A cron in this tap tracks llm-systems-manager releases and bumps every formula
automatically (after re-running the full install tests on macOS + Linux), so
`brew update && brew upgrade` follows new releases.

## Agent

    brew install llm-systems-agent

Prebuilt per-platform binary. Configure: set `MANAGER_URL` in
`$(brew --prefix)/etc/llm-systems-agent/agent_config.yaml`, then

    brew services start llm-systems-agent

(launchd on macOS, a systemd user unit on Linux).

`brew upgrade llm-systems-agent` picks up new releases automatically — a scheduled job in the tap tracks each GitHub Release and bumps the formula. The dashboard's **Admin → Agents → Update** self-update also works, but a later `brew upgrade` replaces the binary again, so prefer `brew` on Homebrew-managed hosts. Uninstall with `brew services stop llm-systems-agent && brew uninstall llm-systems-agent`.

## Control plane (manager + alarm engine)

The manager and alarm engine also install from the project's [Homebrew tap](https://github.com/llmsyscore/homebrew-tap) — macOS (Apple Silicon) or Linux:

```bash
brew tap llmsyscore/tap
brew trust llmsyscore/tap        # newer Homebrew requires trusting third-party taps
brew install llm-systems-manager llm-systems-alarm-engine influxdb@2 influxdb-cli
```

Each formula builds its own Python venv from the release source tarball. Shared config is seeded at `$(brew --prefix)/etc/llm-systems-manager/llm-systems.toml` (alarm-engine ingest/management tokens pre-generated); state lives under `$(brew --prefix)/var/llm-systems-manager/` and survives upgrades. Bring the stack up in this order — the manager's first boot creates the internal CA and issues the alarm engine's TLS cert:

```bash
llm-systems-influx-setup        # onboards InfluxDB, creates the buckets + scoped
                                # tokens, and writes [influxdb.tokens] into the config
brew services start llm-systems-manager
brew services start llm-systems-alarm-engine
```

`llm-systems-influx-setup` (installed by the manager formula) needs both `influxdb@2` (the v2 server — Homebrew's plain `influxdb` formula is InfluxDB 3.x, whose API this stack does not speak) and `influxdb-cli` (the `influx` command ships separately). To do it by hand instead: `brew services start influxdb@2`, `influx setup`, create the buckets/tokens, and fill `[influxdb.tokens]` in the TOML.

`brew upgrade` tracks new releases automatically (the same tap cron that bumps the agent formula bumps these). The dashboard is at `http://<host>:5000`; the alarm engine can run without InfluxDB, but history and alert evaluation stay degraded until the tokens are filled in.

Dashboard: `http://localhost:5000`. Full walkthrough:
[DEPLOYMENT.md](https://github.com/llmsyscore/llm-systems-manager/blob/main/docs/DEPLOYMENT.md#installing-with-homebrew-control-plane)
