# llmsyscore Homebrew tap

Formulae for LLM Systems Manager components on macOS (Apple Silicon).

## Agent

    brew tap llmsyscore/tap
    brew trust llmsyscore/tap   # newer Homebrew requires trusting third-party taps
    brew install llm-systems-agent

Configure: set `MANAGER_URL` in `$(brew --prefix)/etc/llm-systems-agent/agent_config.yaml`, then

    brew services start llm-systems-agent

Upgrade: `brew update && brew upgrade llm-systems-agent` (a cron in this
tap tracks llm-systems-manager releases automatically).

Uninstall: `brew services stop llm-systems-agent && brew uninstall llm-systems-agent`
