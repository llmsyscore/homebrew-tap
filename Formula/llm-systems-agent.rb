class LlmSystemsAgent < Formula
  desc "Monitoring agent for LLM Systems Manager"
  homepage "https://github.com/llmsyscore/llm-systems-manager"
  license "AGPL-3.0-only"

  livecheck do
    url :homepage
    strategy :github_latest
  end

  on_macos do
    depends_on arch: :arm64
    on_arm do
      url "https://github.com/llmsyscore/llm-systems-manager/releases/download/v1.0.7/llm-systems-agent-macos-arm64.tar.gz"
      sha256 "f8a2ba26b536ce5bff79e9efdb4443b1e0ba9c7202599e41c096a6d366f624ec"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/llmsyscore/llm-systems-manager/releases/download/v1.0.7/llm-systems-agent-linux-x86_64.tar.gz"
      sha256 "1f027ff19e8d4d1cdd621736021d47705d7cf9647bd49a0bf3dd3aa40e8bacd7"
    end
    on_arm do
      url "https://github.com/llmsyscore/llm-systems-manager/releases/download/v1.0.7/llm-systems-agent-linux-arm64.tar.gz"
      sha256 "c06e82f7978b0b6a43b059e6dc22fa4d2d3d05c5db152630f28206e842bf1831"
    end
  end

  def install
    seeded = File.read("agent_config.yaml.example")
    bin.install "llm-systems-agent"
    (etc/"llm-systems-agent").install "agent_config.yaml.example"
    # Live config = the full example with AGENT_OS matched to this platform;
    # every other key keeps its runtime-detected default until edited.
    config = etc/"llm-systems-agent/agent_config.yaml"
    unless config.exist?
      seeded = seeded.sub(/^AGENT_OS:(\s+)\S+/, "AGENT_OS:\\1#{OS.mac? ? "macos" : "linux"}")
      config.write seeded
    end
  end

  def caveats
    conflict_hint = if OS.mac?
      <<~EOS
        If a script-based install exists (~/Library/LaunchAgents/com.llm-systems-agent.plist),
        remove it first: both agents would fight over port 8082.
      EOS
    else
      <<~EOS
        If a script/deb/rpm install exists (/etc/systemd/system/llm-systems-agent.service),
        stop and remove it first: both agents would fight over port 8082.
      EOS
    end
    <<~EOS
      Set MANAGER_URL in #{etc}/llm-systems-agent/agent_config.yaml, then:
        brew services start llmsyscore/tap/llm-systems-agent
      Upgrade with `brew upgrade llm-systems-agent` — a manager-triggered agent
      self-update is reverted by the next brew upgrade, so prefer brew here.
      #{conflict_hint}
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
