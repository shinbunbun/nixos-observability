/*
  OpenSearchログ検索エンジン設定モジュール

  このモジュールは以下の機能を提供します：
  - OpenSearch: Elasticsearch互換の高速ログ検索エンジン
  - 単一ノード構成（レプリカなし）
  - インデックステンプレート自動設定
  - ログローテーション

  使用方法:
  - Fluent Bitからログを受信
  - OpenSearch Dashboardsで可視化
*/
{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.services.observability.opensearch;

  # デフォルトのインデックステンプレート
  defaultIndexTemplate = {
    index_patterns = [ "logs-*" ];
    template = {
      settings = {
        number_of_shards = cfg.numberOfShards;
        number_of_replicas = cfg.numberOfReplicas;
        "index.refresh_interval" = "5s";
        "index.codec" = "best_compression";
      };
      mappings = {
        properties = {
          "@timestamp".type = "date";
          level = {
            type = "keyword";
            fields.text.type = "text";
          };
          message = {
            type = "text";
            fields.keyword = {
              type = "keyword";
              ignore_above = 256;
            };
          };
          host.type = "keyword";
          service.type = "keyword";
          unit.type = "keyword";
          job.type = "keyword";
          log_type.type = "keyword";
          method.type = "keyword";
          status.type = "short";
          trace_id.type = "keyword";
        };
      };
    };
  };
in
{
  options.services.observability.opensearch = {
    enable = mkEnableOption "OpenSearch log search engine";

    port = mkOption {
      type = types.port;
      default = 9200;
      description = "HTTP port for OpenSearch";
    };

    transportPort = mkOption {
      type = types.port;
      default = 9300;
      description = "Transport port for OpenSearch node communication";
    };

    clusterName = mkOption {
      type = types.str;
      default = "opensearch-logs";
      description = "OpenSearch cluster name";
    };

    nodeName = mkOption {
      type = types.str;
      default = config.networking.hostName;
      description = "OpenSearch node name";
    };

    heapSize = mkOption {
      type = types.str;
      default = "8g";
      description = "JVM heap size (e.g., '8g', '4g')";
    };

    memoryMax = mkOption {
      type = types.ints.positive;
      default = 10737418240; # 10GB
      description = "Maximum memory usage in bytes";
    };

    numberOfShards = mkOption {
      type = types.ints.positive;
      default = 1;
      description = "Default number of shards for indices";
    };

    numberOfReplicas = mkOption {
      type = types.ints.unsigned;
      default = 0;
      description = "Default number of replicas for indices";
    };

    indexTemplate = mkOption {
      type = types.attrs;
      default = defaultIndexTemplate;
      description = "Index template for logs-* indices";
    };

    enableSecurity = mkOption {
      type = types.bool;
      default = false;
      description = "Enable OpenSearch security plugin";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open firewall ports for OpenSearch";
    };

    enableLogRotation = mkOption {
      type = types.bool;
      default = true;
      description = "Enable log rotation for OpenSearch logs";
    };
  };

  config = mkIf cfg.enable {
    # OpenSearch設定
    services.opensearch = {
      enable = true;
      package = pkgs.opensearch;

      settings = {
        "cluster.name" = cfg.clusterName;
        "node.name" = cfg.nodeName;
        "network.host" = "0.0.0.0";
        "http.port" = cfg.port;
        "transport.port" = cfg.transportPort;
        "discovery.type" = "single-node";

        # パフォーマンスチューニング
        "indices.queries.cache.size" = "20%";
        "indices.requests.cache.size" = "5%";
        "indices.fielddata.cache.size" = "30%";

        # スレッドプール設定
        "thread_pool.write.queue_size" = 1000;
        "thread_pool.search.queue_size" = 2000;

        # セキュリティプラグイン
        "plugins.security.disabled" = !cfg.enableSecurity;

        "action.auto_create_index" = true;
      };

      extraJavaOptions = [
        "-Xms${cfg.heapSize}"
        "-Xmx${cfg.heapSize}"
        "-XX:+UseG1GC"
        "-XX:G1ReservePercent=25"
        "-XX:InitiatingHeapOccupancyPercent=30"
        "-XX:MaxGCPauseMillis=200"
        "-XX:+ParallelRefProcEnabled"
      ];
    };

    # systemdサービス設定
    systemd.services.opensearch = {
      serviceConfig = {
        MemoryMax = lib.mkForce "${toString cfg.memoryMax}";
        MemoryHigh = "${toString (cfg.memoryMax - 2147483648)}";
        Restart = lib.mkForce "on-failure";
        RestartSec = lib.mkForce "30s";
        TimeoutStartSec = lib.mkForce "300s";
        TimeoutStopSec = lib.mkForce "120s";
      };

      postStart = lib.mkAfter ''
        # OpenSearch起動待機
        for i in {1..60}; do
          if ${pkgs.curl}/bin/curl -s http://localhost:${toString cfg.port}/_cluster/health > /dev/null 2>&1; then
            echo "OpenSearch is ready"
            break
          fi
          echo "Waiting for OpenSearch to start... ($i/60)"
          sleep 5
        done

        # インデックステンプレート登録
        ${pkgs.curl}/bin/curl -X PUT "http://localhost:${toString cfg.port}/_index_template/logs-template" \
          -H "Content-Type: application/json" \
          -d '${builtins.toJSON cfg.indexTemplate}' || true

        echo "OpenSearch initialization completed"
      '';
    };

    # ファイアウォール設定
    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [
      cfg.port
      cfg.transportPort
    ];

    # システムパッケージ
    environment.systemPackages = with pkgs; [
      opensearch
      curl
      jq
    ];

    # ログローテーション
    services.logrotate.settings.opensearch = mkIf cfg.enableLogRotation {
      files = "/var/lib/opensearch/logs/*.log";
      rotate = 7;
      frequency = "daily";
      compress = true;
      delaycompress = true;
      missingok = true;
      notifempty = true;
    };
  };
}
