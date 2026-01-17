/*
  OpenSearch Dashboards設定モジュール（Docker版）

  このモジュールは以下の機能を提供します：
  - OpenSearch Dashboards: ログ検索・可視化UI（Dockerコンテナ）
  - OpenSearchとの連携
  - ダッシュボード作成、ログエクスプローラー、可視化機能

  使用方法:
  - OpenSearch と一緒に使用
  - ブラウザからアクセスしてログを可視化
*/
{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.services.observability.opensearchDashboards;
in
{
  options.services.observability.opensearchDashboards = {
    enable = mkEnableOption "OpenSearch Dashboards log visualization UI";

    port = mkOption {
      type = types.port;
      default = 5601;
      description = "Port for OpenSearch Dashboards web interface";
    };

    opensearchUrl = mkOption {
      type = types.str;
      default = "http://localhost:9200";
      description = "OpenSearch URL to connect to";
      example = "http://192.168.1.4:9200";
    };

    serverName = mkOption {
      type = types.str;
      default = "${config.networking.hostName}-dashboards";
      description = "Server name for OpenSearch Dashboards";
    };

    dockerImage = mkOption {
      type = types.str;
      default = "opensearchproject/opensearch-dashboards:2.19.2";
      description = "Docker image for OpenSearch Dashboards";
    };

    enableSecurity = mkOption {
      type = types.bool;
      default = false;
      description = "Enable OpenSearch Dashboards security plugin";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open firewall port for OpenSearch Dashboards";
    };

    enableLogRotation = mkOption {
      type = types.bool;
      default = true;
      description = "Enable log rotation for Docker container logs";
    };
  };

  config = mkIf cfg.enable {
    # Dockerを有効化
    virtualisation.docker.enable = true;

    # OpenSearch Dashboards コンテナ
    virtualisation.oci-containers = {
      backend = "docker";
      containers.opensearch-dashboards = {
        image = cfg.dockerImage;
        autoStart = true;
        log-driver = "json-file";

        ports = [ "${toString cfg.port}:5601" ];

        environment = {
          OPENSEARCH_HOSTS = cfg.opensearchUrl;
          DISABLE_SECURITY_DASHBOARDS_PLUGIN = toString (!cfg.enableSecurity);
          SERVER_HOST = "0.0.0.0";
          SERVER_NAME = cfg.serverName;
          LOGGING_VERBOSE = "false";
        };

        extraOptions = [
          "--health-cmd=curl -f http://localhost:5601/api/status || exit 1"
          "--health-interval=30s"
          "--health-timeout=10s"
          "--health-retries=3"
          "--health-start-period=60s"
          "--add-host=host.docker.internal:host-gateway"
        ];
      };
    };

    # systemdサービス設定
    systemd.services.docker-opensearch-dashboards = {
      after = [ "opensearch.service" ];
      requires = [ "opensearch.service" ];

      serviceConfig = {
        Restart = lib.mkForce "on-failure";
        RestartSec = lib.mkForce "30s";
        TimeoutStartSec = lib.mkForce "300s";
        TimeoutStopSec = lib.mkForce "60s";
      };
    };

    # 起動確認サービス
    systemd.services.opensearch-dashboards-wait = {
      description = "Wait for OpenSearch Dashboards to be ready";
      after = [ "docker-opensearch-dashboards.service" ];
      wants = [ "docker-opensearch-dashboards.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "opensearch-dashboards-wait" ''
          echo "Waiting for OpenSearch Dashboards to be ready..."
          for i in {1..60}; do
            if ${pkgs.curl}/bin/curl -f http://localhost:${toString cfg.port}/api/status > /dev/null 2>&1; then
              echo "OpenSearch Dashboards is ready!"
              exit 0
            fi
            echo "Attempt $i/60: waiting..."
            sleep 5
          done
          echo "Warning: OpenSearch Dashboards did not become ready"
          exit 1
        '';
      };
    };

    # ファイアウォール設定
    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ cfg.port ];

    # システムパッケージ
    environment.systemPackages = with pkgs; [
      docker
      curl
    ];

    # ログローテーション
    services.logrotate.settings.docker-opensearch-dashboards = mkIf cfg.enableLogRotation {
      files = "/var/lib/docker/containers/*-opensearch-dashboards*/*.log";
      rotate = 7;
      frequency = "daily";
      compress = true;
      delaycompress = true;
      missingok = true;
      notifempty = true;
    };
  };
}
