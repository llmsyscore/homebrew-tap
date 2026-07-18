class LlmSystemsAgent < Formula
  desc "Monitoring agent for LLM Systems Manager"
  homepage "https://github.com/llmsyscore/llm-systems-manager"
  url "https://github.com/llmsyscore/llm-systems-manager/releases/download/v1.0.5/llm-systems-agent-macos-arm64.tar.gz"
  sha256 "8216d53343d6c34cde4d916ee8849768d6d787aa4b114b1ecbf20b3383d88148"
  license "AGPL-3.0-only"

  livecheck do
    url :homepage
    strategy :github_latest
  end

  depends_on arch: :arm64
  depends_on :macos

  def install
    bin.install "llm-systems-agent"
    (etc/"llm-systems-agent").install "agent_config.yaml.example"
    # Minimal live config: blank values are ignored at load, so the agent
    # boots on detected defaults until the operator fills in MANAGER_URL.
    config = etc/"llm-systems-agent/agent_config.yaml"
    unless config.exist?
      config.write <<~EOS
        # llm-systems-agent config — set MANAGER_URL to your manager, e.g.
        # "http://manager-host:5000". Full key reference: agent_config.yaml.example
        # (do not copy it wholesale — its AGENT_OS/defaults are Linux-oriented).
        MANAGER_URL: ""
      EOS
    end
  end

  def caveats
    <<~EOS
      Set MANAGER_URL in #{etc}/llm-systems-agent/agent_config.yaml, then:
        brew services start llmsyscore/tap/llm-systems-agent
      Upgrade with `brew upgrade llm-systems-agent` — a manager-triggered agent
      self-update is reverted by the next brew upgrade, so prefer brew here.
      If a script-based install exists (~/Library/LaunchAgents/com.llm-systems-agent.plist),
      remove it first: both agents would fight over port 8082.
    EOS
  end

  service do
    run [opt_bin/"llm-systems-agent"]
    working_dir etc/"llm-systems-agent"
    keep_alive true
    log_path var/"log/llm-systems-agent/agent.log"
    error_log_path var/"log/llm-systems-agent/agent.err.log"
  end

  test do
    assert_match(/^v\d{4}\.\d{2}\.\d{2}/, shell_output("#{bin}/llm-systems-agent --version"))
  end
end
