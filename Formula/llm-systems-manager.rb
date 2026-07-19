class LlmSystemsManager < Formula
  desc "Real-time monitoring + control panel for a small LLM lab (manager)"
  homepage "https://github.com/llmsyscore/llm-systems-manager"
  url "https://github.com/llmsyscore/llm-systems-manager/releases/download/v1.0.7/llm-systems-manager-v1.0.7.tar.gz"
  sha256 "be3f9a9e5eea7279094e3863db1f6d1f49250a110cb66d1585702d9ccdf59b54"
  license "AGPL-3.0-only"

  livecheck do
    url :homepage
    strategy :github_latest
  end

  depends_on "python@3.12"

  def install
    libexec.install Dir["*"]
    # The typed config loader ships as a tracked .example; materialise it.
    cp libexec/"config/unified_config.py.example", libexec/"config/unified_config.py"
    system formula_opt_bin("python@3.12")/"python3.12", "-m", "venv", libexec/"venv"
    system libexec/"venv/bin/pip", "install", "--upgrade", "pip"
    system libexec/"venv/bin/pip", "install", "-r",
           libexec/"llm-systems-manager/backend/requirements.txt"
  end

  def post_install
    (var/"llm-systems-manager/data").mkpath
    (var/"llm-systems-manager/ae-data").mkpath
    (var/"log/llm-systems-manager").mkpath
    # State dirs symlink into var so they survive upgrades; ae-data is shared
    # with the alarm-engine keg (manager first boot writes ae-tls there).
    mgr_data = libexec/"data"
    rm_r mgr_data if mgr_data.symlink? || mgr_data.exist?
    ln_s var/"llm-systems-manager/data", mgr_data
    ae_data = libexec/"llm-systems-alarm-engine/data"
    rm_r ae_data if ae_data.symlink? || ae_data.exist?
    ln_s var/"llm-systems-manager/ae-data", ae_data
    ENV["LSM_BREW_EXAMPLE"] = (libexec/"config/llm-systems.toml.example").to_s
    ENV["LSM_BREW_CONFIG"] = (etc/"llm-systems-manager/llm-systems.toml").to_s
    ENV["LSM_BREW_LOG_DIR"] = (var/"log/llm-systems-manager").to_s
    system "/bin/bash", libexec/"tools/installer/brew-seed-config.sh"
  end

  def caveats
    <<~EOS
      Shared config (also read by llm-systems-alarm-engine):
        #{etc}/llm-systems-manager/llm-systems.toml
      Start the manager BEFORE the alarm engine — its first boot creates the
      internal CA and issues the alarm engine's TLS cert:
        brew services start llmsyscore/tap/llm-systems-manager
      Metric history needs InfluxDB v2: `brew install influxdb`, run
      `influx setup`, then fill [influxdb] + [influxdb.tokens] in the config.
      Dashboard: http://localhost:5000. Don't mix with a script/package
      install on the same host — both would fight over port 5000.
    EOS
  end

  service do
    run [opt_libexec/"venv/bin/python3", opt_libexec/"llm-systems-manager/backend/llm-systems-manager.py"]
    working_dir opt_libexec/"llm-systems-manager"
    environment_variables PYTHONUNBUFFERED: "1", LLM_SYSTEMS_CONFIG: etc/"llm-systems-manager/llm-systems.toml"
    keep_alive true
    log_path var/"log/llm-systems-manager/manager.stdout.log"
    error_log_path var/"log/llm-systems-manager/manager.stderr.log"
  end

  test do
    system libexec/"venv/bin/python3", "-c",
           "import flask, cheroot, websockets, aiohttp, cryptography, psutil"
    assert_path_exists libexec/"config/unified_config.py"
  end
end
