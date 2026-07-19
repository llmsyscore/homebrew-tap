class LlmSystemsAlarmEngine < Formula
  desc "Alarm engine for LLM Systems Manager (rules, alerts, notifications)"
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
           libexec/"llm-systems-alarm-engine/requirements.txt"
    # watchfiles ships a prebuilt .so whose dylib id breaks Homebrew's macOS
    # relocation; only uvicorn --reload uses it, which this launcher never does.
    quiet_system libexec/"venv/bin/pip", "uninstall", "-y", "watchfiles"
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
    (var/"llm-systems-manager/ae-data").mkpath
    (var/"log/llm-systems-manager").mkpath
    # SQLite DBs + ae-tls.{crt,key} live in var, shared with the manager keg.
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
      Config is shared with llm-systems-manager (InfluxDB + token setup is
      covered in that formula's caveats):
        #{etc}/llm-systems-manager/llm-systems.toml
      Start llm-systems-manager first — its first boot issues this engine's
      TLS cert — then:
        brew services start llmsyscore/tap/llm-systems-alarm-engine
    EOS
  end

  service do
    run [opt_libexec/"venv/bin/python3", "-m", "backend.alarm_engine"]
    working_dir opt_libexec/"llm-systems-alarm-engine"
    environment_variables PYTHONUNBUFFERED: "1", LLM_SYSTEMS_CONFIG: etc/"llm-systems-manager/llm-systems.toml"
    keep_alive true
    log_path var/"log/llm-systems-manager/alarm-engine.stdout.log"
    error_log_path var/"log/llm-systems-manager/alarm-engine.stderr.log"
  end

  test do
    system libexec/"venv/bin/python3", "-c",
           "import fastapi, uvicorn, influxdb_client, numpy, scipy, httpx"
    assert_path_exists libexec/"config/unified_config.py"
  end
end
