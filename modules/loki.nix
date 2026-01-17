/*
  Lokiログ集約システム設定モジュール

  このモジュールは以下の機能を提供します：
  - Loki: ログ集約・検索エンジン
  - データ保持期間の設定
  - Grafanaとの統合
  - アラートルール評価（Ruler）

  使用方法:
  - Promtail または Fluent Bit からログを受信
  - Grafana データソースとして登録
*/
{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.services.observability.loki;
in
{
  options.services.observability.loki = {
    enable = mkEnableOption "Loki log aggregation system";

    port = mkOption {
      type = types.port;
      default = 3100;
      description = "Port for Loki HTTP API";
    };

    grpcPort = mkOption {
      type = types.port;
      default = 9095;
      description = "Port for Loki gRPC (internal communication)";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/loki";
      description = "Directory for Loki data storage";
    };

    retentionDays = mkOption {
      type = types.ints.positive;
      default = 30;
      description = "Number of days to retain log data";
    };

    # データ取り込み設定
    ingestionRateLimit = mkOption {
      type = types.ints.positive;
      default = 52428800; # 50MB/s
      description = "Ingestion rate limit in bytes per second";
    };

    ingestionBurstSize = mkOption {
      type = types.ints.positive;
      default = 104857600; # 100MB
      description = "Ingestion burst size in bytes";
    };

    chunkTargetSize = mkOption {
      type = types.ints.positive;
      default = 1572864; # 1.5MB
      description = "Target size for chunks in bytes";
    };

    # リソース制限
    memoryMax = mkOption {
      type = types.str;
      default = "2G";
      description = "Maximum memory usage for Loki service";
    };

    memoryHigh = mkOption {
      type = types.str;
      default = "1500M";
      description = "Memory high watermark for Loki service";
    };

    cpuQuota = mkOption {
      type = types.str;
      default = "200%";
      description = "CPU quota for Loki service";
    };

    # Alertmanager連携
    alertmanagerUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Alertmanager URL for ruler to send alerts";
      example = "http://localhost:9093";
    };

    # アラートルール
    rulesFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to Loki alert rules YAML file";
    };

    # ファイアウォール
    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open firewall ports for Loki";
    };
  };

  config = mkIf cfg.enable {
    # Loki設定
    services.loki = {
      enable = true;

      configuration = {
        auth_enabled = false;

        server = {
          http_listen_port = cfg.port;
          grpc_listen_port = cfg.grpcPort;
          log_level = "info";
        };

        ingester = {
          lifecycler = {
            address = "127.0.0.1";
            ring = {
              kvstore.store = "inmemory";
              replication_factor = 1;
            };
            final_sleep = "0s";
          };
          chunk_idle_period = "5m";
          chunk_retain_period = "30s";
          chunk_target_size = cfg.chunkTargetSize;
          wal = {
            enabled = true;
            dir = "${cfg.dataDir}/wal";
          };
        };

        schema_config.configs = [
          {
            from = "2020-01-01";
            store = "boltdb-shipper";
            object_store = "filesystem";
            schema = "v11";
            index = {
              prefix = "loki_index_";
              period = "24h";
            };
          }
        ];

        storage_config = {
          boltdb_shipper = {
            active_index_directory = "${cfg.dataDir}/boltdb-shipper-active";
            cache_location = "${cfg.dataDir}/boltdb-shipper-cache";
          };
          filesystem.directory = "${cfg.dataDir}/chunks";
        };

        limits_config = {
          ingestion_rate_mb = cfg.ingestionRateLimit / 1048576;
          ingestion_burst_size_mb = cfg.ingestionBurstSize / 1048576;
          max_query_parallelism = 32;
          per_stream_rate_limit = "10MB";
          per_stream_rate_limit_burst = "20MB";
          max_label_names_per_series = 30;
          max_label_value_length = 2048;
          max_label_name_length = 1024;
          max_entries_limit_per_query = 100000;
          reject_old_samples = true;
          reject_old_samples_max_age = "168h";
          allow_structured_metadata = false;
        };

        table_manager = {
          retention_deletes_enabled = true;
          retention_period = "${toString cfg.retentionDays}d";
        };

        compactor = {
          working_directory = "${cfg.dataDir}/compactor";
          compaction_interval = "10m";
          retention_enabled = true;
          retention_delete_delay = "2h";
          retention_delete_worker_count = 150;
          delete_request_store = "filesystem";
        };

        ruler = mkIf (cfg.alertmanagerUrl != null) {
          storage = {
            type = "local";
            local.directory = "${cfg.dataDir}/rules";
          };
          rule_path = "${cfg.dataDir}/rules-temp";
          alertmanager_url = cfg.alertmanagerUrl;
          ring.kvstore.store = "inmemory";
          enable_api = true;
          enable_alertmanager_v2 = true;
        };

        query_range.results_cache.cache = {
          embedded_cache = {
            enabled = true;
            max_size_mb = 100;
          };
        };

        frontend.compress_responses = true;
      };
    };

    # systemdサービスの設定
    systemd.services.loki = {
      serviceConfig = {
        MemoryMax = cfg.memoryMax;
        MemoryHigh = cfg.memoryHigh;
        CPUQuota = cfg.cpuQuota;
        Restart = lib.mkForce "on-failure";
        RestartSec = "10s";
        StateDirectory = "loki";
        StateDirectoryMode = "0750";
      };

      preStart = mkIf (cfg.rulesFile != null) ''
        # ルールディレクトリのセットアップ
        if [ -d ${cfg.dataDir}/rules ]; then
          chown -R loki:loki ${cfg.dataDir}/rules || true
        fi
        mkdir -p ${cfg.dataDir}/rules/fake
        cp -f ${cfg.rulesFile} ${cfg.dataDir}/rules/fake/rules.yaml
        chown -R loki:loki ${cfg.dataDir}/rules
      '';
    };

    # ファイアウォール設定
    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [
      cfg.port
      cfg.grpcPort
    ];

    # システムパッケージ
    environment.systemPackages = with pkgs; [
      loki
      grafana-loki
    ];
  };
}
