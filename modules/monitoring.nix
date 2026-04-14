/*
  監視システム設定モジュール

  このモジュールは Node Exporter を設定します。
  メトリクス収集・アラート評価・通知は k3s クラスタの VictoriaMetrics スタック
  (VMCluster, VMAgent, VMAlert, VMAlertmanager) に移管済み。
  NixOS 側では各ホストがスクレイプ対象として Node Exporter を提供するのみ。
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
    enable = mkEnableOption "Node Exporter for system metrics";

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

    # ファイアウォール設定
    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open firewall port for Node Exporter";
    };
  };

  config = mkIf cfg.enable {
    # Node Exporter設定
    services.prometheus.exporters.node = mkIf cfg.nodeExporter.enable {
      enable = true;
      port = cfg.nodeExporter.port;
      enabledCollectors = cfg.nodeExporter.enabledCollectors;
      extraFlags = cfg.nodeExporter.extraFlags;
    };

    # ファイアウォール設定
    networking.firewall.allowedTCPPorts = mkIf (cfg.openFirewall && cfg.nodeExporter.enable) [
      cfg.nodeExporter.port
    ];

    # システムパッケージ
    environment.systemPackages = mkIf cfg.nodeExporter.enable [
      pkgs.prometheus-node-exporter
    ];
  };
}
