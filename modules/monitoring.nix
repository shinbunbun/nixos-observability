/*
  監視システム設定モジュール

  このモジュールは以下の監視コンポーネントを設定します：
  - Prometheus: メトリクス収集と保存
  - Node Exporter: システムメトリクスの公開
  - Grafana: メトリクスの可視化
  - SNMP Exporter: ネットワークデバイス監視（MikroTik RouterOS）

  外部アクセスはCloudflare TunnelやリバースプロキシURL経由で提供されます。
*/
{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.services.observability.monitoring;
in
{
  options.services.observability.monitoring = {
    enable = mkEnableOption "Monitoring stack (Prometheus, Grafana, Node Exporter, SNMP Exporter)";

    # Prometheus設定
    prometheus = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Prometheus metrics collection";
      };

      port = mkOption {
        type = types.port;
        default = 9090;
        description = "Port for Prometheus web interface";
      };

      retentionDays = mkOption {
        type = types.ints.positive;
        default = 30;
        description = "Number of days to retain metrics data";
      };

      scrapeInterval = mkOption {
        type = types.str;
        default = "15s";
        description = "How frequently to scrape targets";
      };

      evaluationInterval = mkOption {
        type = types.str;
        default = "15s";
        description = "How frequently to evaluate rules";
      };

      scrapeConfigs = mkOption {
        type = types.listOf types.attrs;
        default = [ ];
        description = ''
          Prometheus scrape configurations.
          See https://prometheus.io/docs/prometheus/latest/configuration/configuration/#scrape_config
        '';
      };
    };

    # Node Exporter設定
    nodeExporter = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Node Exporter for system metrics";
      };

      port = mkOption {
        type = types.port;
        default = 9100;
        description = "Port for Node Exporter metrics endpoint";
      };

      enabledCollectors = mkOption {
        type = types.listOf types.str;
        default = [
          "cpu"
          "diskstats"
          "filesystem"
          "loadavg"
          "meminfo"
          "netdev"
          "stat"
          "time"
          "vmstat"
          "systemd"
          "processes"
          "hwmon"
          "thermal_zone"
          "interrupts"
          "powersupplyclass"
          "tcpstat"
        ];
        description = "List of collectors to enable";
      };

      extraFlags = mkOption {
        type = types.listOf types.str;
        default = [
          "--collector.filesystem.mount-points-exclude=^/(dev|proc|sys|run/user/.+)($|/)"
          "--collector.netdev.device-exclude=^(veth.*|br.*|docker.*|virbr.*|lo|wlp[0-9]s0)$"
        ];
        description = "Extra command-line flags for Node Exporter";
      };
    };

    # SNMP Exporter設定
    snmpExporter = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable SNMP Exporter for network device monitoring";
      };

      port = mkOption {
        type = types.port;
        default = 9116;
        description = "Port for SNMP Exporter";
      };

      configFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to SNMP Exporter configuration file (snmp.yml)";
      };
    };

    # Grafana設定
    grafana = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Grafana for metrics visualization";
      };

      port = mkOption {
        type = types.port;
        default = 3000;
        description = "Port for Grafana web interface";
      };

      domain = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Domain name for Grafana (e.g., grafana.example.com)";
        example = "grafana.example.com";
      };

      adminUser = mkOption {
        type = types.str;
        default = "admin";
        description = "Admin username for Grafana";
      };

      adminPassword = mkOption {
        type = types.str;
        default = "admin";
        description = ''
          Initial admin password for Grafana.
          This should be changed after first login.
        '';
      };

      disableReporting = mkOption {
        type = types.bool;
        default = true;
        description = "Disable Grafana analytics and update checks";
      };

      # OAuth設定
      oauth = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable OAuth2/OIDC authentication";
        };

        name = mkOption {
          type = types.str;
          default = "OAuth";
          description = "OAuth provider name (displayed on login page)";
        };

        environmentFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = ''
            Path to file containing OAuth environment variables:
            GRAFANA_OAUTH_CLIENT_ID=...
            GRAFANA_OAUTH_CLIENT_SECRET=...
          '';
        };

        authUrl = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "OAuth authorization URL";
          example = "https://auth.example.com/application/o/authorize/";
        };

        tokenUrl = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "OAuth token URL";
          example = "https://auth.example.com/application/o/token/";
        };

        apiUrl = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "OAuth user info API URL";
          example = "https://auth.example.com/application/o/userinfo/";
        };

        scopes = mkOption {
          type = types.str;
          default = "openid email profile";
          description = "OAuth scopes to request";
        };

        roleAttributePath = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            JMESPath expression to extract role from OAuth user info.
            Example: "contains(groups[*], 'Grafana Admins') && 'Admin' || 'Viewer'"
          '';
        };

        autoLogin = mkOption {
          type = types.bool;
          default = false;
          description = "Enable automatic login via OAuth";
        };

        allowSignUp = mkOption {
          type = types.bool;
          default = true;
          description = "Allow users to sign up via OAuth";
        };
      };

      # ダッシュボードプロビジョニング
      dashboards = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable dashboard provisioning";
        };

        path = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Path to directory containing dashboard JSON files";
        };
      };
    };

    # データソース設定
    datasources = {
      prometheus = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Add Prometheus as a datasource";
        };

        url = mkOption {
          type = types.str;
          default = "http://localhost:${toString cfg.prometheus.port}";
          description = "Prometheus URL";
        };

        isDefault = mkOption {
          type = types.bool;
          default = true;
          description = "Set Prometheus as the default datasource";
        };
      };

      loki = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Add Loki as a datasource";
        };

        url = mkOption {
          type = types.str;
          default = "http://localhost:3100";
          description = "Loki URL";
        };

        maxLines = mkOption {
          type = types.int;
          default = 1000;
          description = "Maximum number of log lines to display";
        };
      };
    };

    # ファイアウォール設定
    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open firewall ports for monitoring services";
    };
  };

  config = mkIf cfg.enable {
    # Prometheus設定（メインサービスとエクスポーターを統合）
    services.prometheus = mkMerge [
      (mkIf cfg.prometheus.enable {
        enable = true;
        port = cfg.prometheus.port;
        retentionTime = "${toString cfg.prometheus.retentionDays}d";

        globalConfig = {
          scrape_interval = cfg.prometheus.scrapeInterval;
          evaluation_interval = cfg.prometheus.evaluationInterval;
        };

        scrapeConfigs = cfg.prometheus.scrapeConfigs;
      })
      {
        # Node Exporter設定
        exporters.node = mkIf cfg.nodeExporter.enable {
          enable = true;
          port = cfg.nodeExporter.port;
          enabledCollectors = cfg.nodeExporter.enabledCollectors;
          extraFlags = cfg.nodeExporter.extraFlags;
        };

        # SNMP Exporter設定
        exporters.snmp = mkIf cfg.snmpExporter.enable {
          enable = true;
          port = cfg.snmpExporter.port;
          configurationPath = mkIf (cfg.snmpExporter.configFile != null) cfg.snmpExporter.configFile;
        };
      }
    ];

    # Grafana設定
    services.grafana = mkIf cfg.grafana.enable {
      enable = true;

      settings = {
        server =
          {
            http_addr = "127.0.0.1";
            http_port = cfg.grafana.port;
          }
          // optionalAttrs (cfg.grafana.domain != null) {
            domain = cfg.grafana.domain;
            root_url = "https://${cfg.grafana.domain}";
          };

        security = {
          admin_user = cfg.grafana.adminUser;
          admin_password = cfg.grafana.adminPassword;
          disable_initial_admin_creation = false;
        };

        "auth.anonymous".enabled = false;

        # OAuth設定
        "auth.generic_oauth" = mkIf cfg.grafana.oauth.enable {
          enabled = true;
          name = cfg.grafana.oauth.name;
          allow_sign_up = cfg.grafana.oauth.allowSignUp;
          client_id = "$__env{GRAFANA_OAUTH_CLIENT_ID}";
          client_secret = "$__env{GRAFANA_OAUTH_CLIENT_SECRET}";
          scopes = cfg.grafana.oauth.scopes;
          auth_url = mkIf (cfg.grafana.oauth.authUrl != null) cfg.grafana.oauth.authUrl;
          token_url = mkIf (cfg.grafana.oauth.tokenUrl != null) cfg.grafana.oauth.tokenUrl;
          api_url = mkIf (cfg.grafana.oauth.apiUrl != null) cfg.grafana.oauth.apiUrl;
          role_attribute_path = mkIf (cfg.grafana.oauth.roleAttributePath != null) cfg.grafana.oauth.roleAttributePath;
          auto_login = cfg.grafana.oauth.autoLogin;
        };

        analytics = mkIf cfg.grafana.disableReporting {
          reporting_enabled = false;
          check_for_updates = false;
        };
      };

      # データソースとダッシュボードのプロビジョニング
      provision = {
        enable = true;

        datasources.settings.datasources =
          (optional cfg.datasources.prometheus.enable {
            name = "Prometheus";
            type = "prometheus";
            access = "proxy";
            url = cfg.datasources.prometheus.url;
            jsonData.timeInterval = cfg.prometheus.scrapeInterval;
            isDefault = cfg.datasources.prometheus.isDefault;
          })
          ++ (optional cfg.datasources.loki.enable {
            name = "Loki";
            type = "loki";
            access = "proxy";
            url = cfg.datasources.loki.url;
            jsonData = {
              maxLines = cfg.datasources.loki.maxLines;
            };
          });

        dashboards.settings.providers = mkIf (cfg.grafana.dashboards.enable && cfg.grafana.dashboards.path != null) [
          {
            name = "observability";
            orgId = 1;
            folder = "";
            type = "file";
            disableDeletion = false;
            updateIntervalSeconds = 10;
            allowUiUpdates = true;
            options.path = cfg.grafana.dashboards.path;
          }
        ];
      };
    };

    # Grafana用の環境変数設定（OAuth）
    systemd.services.grafana.serviceConfig = mkIf (
      cfg.grafana.enable && cfg.grafana.oauth.enable && cfg.grafana.oauth.environmentFile != null
    ) {
      EnvironmentFile = [ cfg.grafana.oauth.environmentFile ];
    };

    # ファイアウォール設定
    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall (
      (optional cfg.prometheus.enable cfg.prometheus.port)
      ++ (optional cfg.nodeExporter.enable cfg.nodeExporter.port)
      ++ (optional cfg.grafana.enable cfg.grafana.port)
      ++ (optional cfg.snmpExporter.enable cfg.snmpExporter.port)
    );

    # システムパッケージ
    environment.systemPackages =
      (optional cfg.prometheus.enable pkgs.prometheus)
      ++ (optional cfg.nodeExporter.enable pkgs.prometheus-node-exporter)
      ++ (optional cfg.snmpExporter.enable pkgs.prometheus-snmp-exporter)
      ++ (optional cfg.grafana.enable pkgs.grafana)
      ++ (optional cfg.snmpExporter.enable pkgs.net-snmp);
  };
}
