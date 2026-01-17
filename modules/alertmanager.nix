/*
  Alertmanager設定モジュール

  このモジュールはPrometheusのアラート管理とDiscord通知を設定します：
  - Alertmanager: アラートのルーティングと通知
  - Discord Webhook: アラート通知の送信先
  - アラートルール: 監視対象の異常を検知

  アラートはグループ化され、重複排除された後Discordチャンネルに送信されます。
*/
{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.services.observability.alertmanager;
in
{
  options.services.observability.alertmanager = {
    enable = mkEnableOption "Alertmanager for alert management and Discord notifications";

    port = mkOption {
      type = types.port;
      default = 9093;
      description = "Port for Alertmanager web interface";
    };

    # Discord設定
    discord = {
      webhookUrlFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          Path to file containing Discord webhook URL.
          The file should contain:
          DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...
        '';
      };
    };

    # グローバル設定
    resolveTimeout = mkOption {
      type = types.str;
      default = "5m";
      description = "Time to wait before marking an alert as resolved";
    };

    # グループ設定
    groupBy = mkOption {
      type = types.listOf types.str;
      default = [
        "alertname"
        "cluster"
        "service"
      ];
      description = "Labels to group alerts by";
    };

    groupWait = mkOption {
      type = types.str;
      default = "10s";
      description = "Time to wait before sending initial notification";
    };

    groupInterval = mkOption {
      type = types.str;
      default = "10s";
      description = "Time to wait before sending updates for grouped alerts";
    };

    repeatInterval = mkOption {
      type = types.str;
      default = "1h";
      description = "Time to wait before resending an alert";
    };

    # 重要度別の繰り返し間隔
    criticalRepeatInterval = mkOption {
      type = types.str;
      default = "15m";
      description = "Repeat interval for critical alerts";
    };

    warningRepeatInterval = mkOption {
      type = types.str;
      default = "30m";
      description = "Repeat interval for warning alerts";
    };

    # Prometheusとの連携
    prometheusUrl = mkOption {
      type = types.str;
      default = "localhost:9093";
      description = "Alertmanager URL for Prometheus to connect to";
    };

    # アラートルール
    alertRules = mkOption {
      type = types.listOf types.attrs;
      default = [ ];
      description = ''
        Prometheus alert rule groups.
        Each element should be an attrset with 'name', 'interval', and 'rules'.
      '';
      example = literalExpression ''
        [
          {
            name = "system";
            interval = "30s";
            rules = [
              {
                alert = "InstanceDown";
                expr = "up == 0";
                for = "2m";
                labels.severity = "critical";
                annotations.summary = "Instance {{ $labels.instance }} down";
              }
            ];
          }
        ]
      '';
    };

    checkConfig = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable configuration validation at build time.
        Set to false if using environment variables in config.
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open firewall port for Alertmanager";
    };
  };

  config = mkIf cfg.enable {
    # Alertmanager設定
    services.prometheus.alertmanager = {
      enable = true;
      port = cfg.port;
      checkConfig = cfg.checkConfig;

      configuration = {
        global = {
          resolve_timeout = cfg.resolveTimeout;
        };

        route = {
          receiver = "discord";
          group_by = cfg.groupBy;
          group_wait = cfg.groupWait;
          group_interval = cfg.groupInterval;
          repeat_interval = cfg.repeatInterval;
          routes = [
            {
              match.severity = "critical";
              receiver = "discord";
              repeat_interval = cfg.criticalRepeatInterval;
            }
            {
              match.severity = "warning";
              receiver = "discord";
              repeat_interval = cfg.warningRepeatInterval;
            }
          ];
        };

        receivers = [
          {
            name = "discord";
            discord_configs = [
              {
                webhook_url = "$DISCORD_WEBHOOK_URL";
                send_resolved = true;
              }
            ];
          }
        ];

        inhibit_rules = [
          {
            source_match.severity = "critical";
            target_match.severity = "warning";
            equal = [
              "alertname"
              "instance"
            ];
          }
        ];
      };

      environmentFile = mkIf (cfg.discord.webhookUrlFile != null) cfg.discord.webhookUrlFile;
    };

    # Prometheus側のAlertmanager連携設定
    services.prometheus.alertmanagers = [
      {
        static_configs = [
          {
            targets = [ cfg.prometheusUrl ];
          }
        ];
      }
    ];

    # アラートルール
    services.prometheus.rules = mkIf (cfg.alertRules != [ ]) [
      (builtins.toJSON { groups = cfg.alertRules; })
    ];

    # ファイアウォール設定
    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ cfg.port ];

    # システムパッケージ
    environment.systemPackages = [ pkgs.prometheus-alertmanager ];
  };
}
