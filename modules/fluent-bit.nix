/*
  Fluent Bitログ収集エージェント設定モジュール

  このモジュールは以下の機能を提供します：
  - Fluent Bit: 軽量高速なログ収集・転送エージェント
  - 設定ファイルの柔軟な管理
  - systemd-journalやsyslogからのログ収集
  - LokiやOpenSearchへの送信

  使用方法:
  - 設定ファイルを用意して configFile option で指定
  - または、独自の systemd service を作成
*/
{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.services.observability.fluentBit;
in
{
  options.services.observability.fluentBit = {
    enable = mkEnableOption "Fluent Bit log collection agent";

    package = mkOption {
      type = types.package;
      default = pkgs.fluent-bit;
      description = "Fluent Bit package to use";
    };

    configFile = mkOption {
      type = types.path;
      description = ''
        Path to Fluent Bit configuration file.
        The file should be in Fluent Bit's native configuration format.
      '';
      example = literalExpression "./fluent-bit.conf";
    };

    port = mkOption {
      type = types.port;
      default = 2020;
      description = "HTTP server port for Fluent Bit metrics";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/fluent-bit";
      description = "Directory for Fluent Bit data storage";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Additional packages to make available to Fluent Bit";
      example = literalExpression "[ pkgs.geoip ]";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open firewall ports for Fluent Bit";
    };

    firewallPorts = mkOption {
      type = types.listOf types.port;
      default = [ ];
      description = "Additional firewall ports to open for Fluent Bit";
      example = [ 514 ]; # syslog
    };
  };

  config = mkIf cfg.enable {
    # Fluent Bit systemd service
    systemd.services.fluent-bit = {
      description = "Fluent Bit Log Processor";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/fluent-bit -c ${cfg.configFile}";
        Restart = "on-failure";
        RestartSec = "10s";

        # セキュリティ設定
        DynamicUser = false;
        User = "fluent-bit";
        Group = "fluent-bit";

        # ディレクトリ設定
        StateDirectory = "fluent-bit";
        StateDirectoryMode = "0750";

        # ログアクセス権限
        SupplementaryGroups = [ "systemd-journal" ];

        # 特権ポート（<1024）へのバインド許可
        AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];

        # リソース制限
        MemoryMax = "512M";
        CPUQuota = "100%";
      };
    };

    # fluent-bit ユーザーとグループ
    users.users.fluent-bit = {
      isSystemUser = true;
      group = "fluent-bit";
      description = "Fluent Bit daemon user";
    };

    users.groups.fluent-bit = { };

    # ファイアウォール設定
    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall (
      [ cfg.port ] ++ cfg.firewallPorts
    );

    networking.firewall.allowedUDPPorts = mkIf cfg.openFirewall cfg.firewallPorts;

    # システムパッケージ
    environment.systemPackages = [ cfg.package ] ++ cfg.extraPackages;
  };
}
