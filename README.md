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

Uninstall: `brew services stop llm-systems-agent && brew uninstall llm-systems-agent`

## Control plane (manager + alarm engine)

    brew install llm-systems-manager llm-systems-alarm-engine influxdb

Each formula builds its own Python venv from the release source tarball. Shared
config is seeded at `$(brew --prefix)/etc/llm-systems-manager/llm-systems.toml`
(alarm-engine tokens pre-generated); state lives under
`$(brew --prefix)/var/llm-systems-manager/` and survives upgrades.

Start order matters — the manager's first boot creates the internal CA and
issues the alarm engine's TLS cert:

    brew services start influxdb                # then `influx setup` + put the
                                                # tokens into [influxdb.tokens]
    brew services start llm-systems-manager
    brew services start llm-systems-alarm-engine

Dashboard: `http://localhost:5000`. Full walkthrough:
[DEPLOYMENT.md](https://github.com/llmsyscore/llm-systems-manager/blob/main/docs/DEPLOYMENT.md#installing-with-homebrew-control-plane)
