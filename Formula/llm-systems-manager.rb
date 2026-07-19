class LlmSystemsManager < Formula
  desc "Real-time monitoring + control panel for a small LLM lab (manager)"
  homepage "https://github.com/llmsyscore/llm-systems-manager"
  url "https://github.com/llmsyscore/llm-systems-manager/releases/download/v1.0.10/llm-systems-manager-v1.0.10.tar.gz"
  sha256 "7798f188ffc76f4a88ce3abd106ff38c57b811bc4968cc341222bd17de2e0296"
  license "AGPL-3.0-only"

  livecheck do
    url :homepage
    strategy :github_latest
  end

  depends_on "python@3.12"

  def install
    libexec.install Dir["*"]
    prune_dev_payload
    # The typed config loader ships as a tracked .example; materialise it.
    cp libexec/"config/unified_config.py.example", libexec/"config/unified_config.py"
    system formula_opt_bin("python@3.12")/"python3.12", "-m", "venv", libexec/"venv"
    system libexec/"venv/bin/pip", "install", "--upgrade", "pip"
    system libexec/"venv/bin/pip", "install", "-r",
           libexec/"llm-systems-manager/backend/requirements.txt"
    # Ships from v1.0.8 tarballs — guard so older tarballs still build.
    influx_helper = libexec/"tools/installer/brew-influx-setup.sh"
    if influx_helper.exist?
      influx_helper.chmod 0755
      bin.install_symlink influx_helper => "llm-systems-influx-setup"
    end
  end

  # No dev/CI payload in the keg — mirrors tools/packaging/build-packages.sh.
  def prune_dev_payload
    %w[docker design devel docs/screenshots tools/packaging plans backups data
       .github .claude docker-compose.yml .dockerignore .env.example
       .gitignore .gitattributes .llmsys-release].each do |p|
      rm_r(libexec/p) if (libexec/p).exist? || (libexec/p).symlink?
    end
    Dir[libexec/"tools/installer/ci-*.sh"].each { |f| rm(f) }
    Dir[libexec/"**/{tests,test,__pycache__,.pytest_cache,node_modules}"].each do |d|
      rm_r(d) if File.exist?(d)
    end
    Dir[libexec/"**/{pytest.ini,requirements-dev.txt,.gitignore}"].each do |f|
      rm(f) if File.exist?(f)
    end
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
      Metric history needs InfluxDB v2 (server and CLI are separate formulas):
        brew install influxdb influxdb-cli
        llm-systems-influx-setup   # onboards + creates buckets/tokens + fills the config
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
