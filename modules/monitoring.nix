/*
  監視システム設定モジュール

  このモジュールは以下の監視コンポーネントを設定します：
  - Prometheus: メトリクス収集と保存
  - Node Exporter: システムメトリクスの公開
  - SNMP Exporter: ネットワークデバイス監視（MikroTik RouterOS）

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
    enable = mkEnableOption "Monitoring stack (Prometheus, Node Exporter, SNMP Exporter)";

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

      recordingRules = mkOption {
        type = types.listOf types.attrs;
        default = [ ];
        description = ''
          Prometheus recording rule groups.
          Each element should be an attrset with 'name', 'interval', and 'rules'.
        '';
      };

      externalUrl = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "External URL for Prometheus (used in alert notifications)";
        example = "https://grafana.example.com";
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

    # ファイアウォール設定
    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open firewall ports for monitoring services";
    };
  };

  config = mkIf cfg.enable {
    # Prometheus設定（メインサービスとエクスポーター）
    services.prometheus = {
      enable = mkIf cfg.prometheus.enable true;
      port = cfg.prometheus.port;
      retentionTime = "${toString cfg.prometheus.retentionDays}d";
      webExternalUrl = mkIf (cfg.prometheus.externalUrl != null) cfg.prometheus.externalUrl;

      globalConfig = {
        scrape_interval = cfg.prometheus.scrapeInterval;
        evaluation_interval = cfg.prometheus.evaluationInterval;
      };

      scrapeConfigs = cfg.prometheus.scrapeConfigs;

      # Recording Rules（別ファイルとして生成。rules は alertmanager.nix と結合されて壊れるため ruleFiles を使用）
      ruleFiles = mkIf (cfg.prometheus.recordingRules != [ ]) [
        (pkgs.writeText "recording-rules.json" (
          builtins.toJSON { groups = cfg.prometheus.recordingRules; }
        ))
      ];

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
    };

    # ファイアウォール設定
    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall (
      (optional cfg.prometheus.enable cfg.prometheus.port)
      ++ (optional cfg.nodeExporter.enable cfg.nodeExporter.port)
      ++ (optional cfg.snmpExporter.enable cfg.snmpExporter.port)
    );

    # システムパッケージ
    environment.systemPackages =
      (optional cfg.prometheus.enable pkgs.prometheus)
      ++ (optional cfg.nodeExporter.enable pkgs.prometheus-node-exporter)
      ++ (optional cfg.snmpExporter.enable pkgs.prometheus-snmp-exporter)
      ++ (optional cfg.snmpExporter.enable pkgs.net-snmp);
  };
}
