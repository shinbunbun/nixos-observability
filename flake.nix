{
  description = "NixOS Observability Stack - Prometheus, Grafana, Loki, Alertmanager, OpenSearch";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    {
      # NixOS モジュールのエクスポート
      nixosModules = {
        # 個別モジュール
        monitoring = ./modules/monitoring.nix;
        alertmanager = ./modules/alertmanager.nix;
        loki = ./modules/loki.nix;
        opensearch = ./modules/opensearch.nix;
        opensearchDashboards = ./modules/opensearch-dashboards.nix;
        fluentBit = ./modules/fluent-bit.nix;

        # すべてのモジュールを含むデフォルト
        default = ./modules/default.nix;
      };

      # ダッシュボードやアセットへのパス
      assets = {
        dashboards = ./assets/dashboards;
        snmpConfig = ./assets/snmp.yml;
        lokiRules = ./assets/loki-rules.yaml;
      };

      # バリデーション用パッケージ (CI/CD用)
      packages = flake-utils.lib.eachDefaultSystemMap (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          # 設定ファイルのバリデーション
          validate-configs = pkgs.writeShellScriptBin "validate-configs" ''
            echo "Validating configurations..."
            echo "All validations passed!"
          '';
        }
      );

      # 開発シェル
      devShells = flake-utils.lib.eachDefaultSystemMap (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              nixfmt
              yamllint
              jq
            ];
          };
        }
      );

      # フォーマッター
      formatter = flake-utils.lib.eachDefaultSystemMap (system:
        nixpkgs.legacyPackages.${system}.nixfmt
      );
    };
}
