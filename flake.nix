{
  description = "NixOS Observability Stack - Node Exporter, Fluent Bit";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    {
      # NixOS モジュールのエクスポート
      nixosModules = {
        # 個別モジュール
        monitoring = ./modules/monitoring.nix;
        fluentBit = ./modules/fluent-bit.nix;

        # すべてのモジュールを含むデフォルト
        default = ./modules/default.nix;
      };

      # バリデーション用パッケージ (CI/CD用)
      #
      # monitoring / fluentBit モジュールを nixpkgs.lib.nixosSystem で
      # 実際に評価し、オプション型ミス・imports エラー・config 不整合を
      # CI で検出できるようにする。echo するだけの stub ではなく、
      # 評価結果の config.system.build.toplevel を参照することで
      # モジュール評価が成功しないとビルドが失敗する。
      #
      # NixOS モジュールの評価なので Linux システムに限定する
      # (darwin で nixosSystem を評価すると unsupported system エラーになる)。
      packages = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          # monitoring (nodeExporter + processExporter) と
          # fluentBit (configFile 注入) の両方を有効化した最小システム。
          evalSystem = nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [
              self.nixosModules.monitoring
              self.nixosModules.fluentBit
              (
                { pkgs, ... }:
                {
                  # 評価に必要な最小限のシステム設定
                  boot.loader.grub.enable = false;
                  fileSystems."/" = {
                    device = "/dev/disk/by-label/nixos";
                    fsType = "ext4";
                  };
                  system.stateVersion = "24.11";

                  # monitoring: nodeExporter + processExporter を両方有効化
                  services.observability.monitoring = {
                    enable = true;
                    nodeExporter.enable = true;
                    processExporter.enable = true;
                  };

                  # fluentBit: configFile を注入して評価
                  services.observability.fluentBit = {
                    enable = true;
                    configFile = pkgs.writeText "fluent-bit.conf" ''
                      [SERVICE]
                          Flush 1
                          Log_Level info

                      [INPUT]
                          Name dummy

                      [OUTPUT]
                          Name stdout
                          Match *
                    '';
                  };
                }
              )
            ];
          };
        in
        {
          # モジュール評価バリデーション
          # monitoring / fluentBit を import した最小 NixOS システムを
          # 評価し、その toplevel をビルドする。評価が通れば成功。
          validate-configs = evalSystem.config.system.build.toplevel;
        }
      );

      # 開発シェル
      devShells = flake-utils.lib.eachDefaultSystemMap (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              nixfmt-tree
              yamllint
              jq
            ];
          };
        }
      );

      # フォーマッター
      formatter = flake-utils.lib.eachDefaultSystemMap (
        system: nixpkgs.legacyPackages.${system}.nixfmt-tree
      );
    };
}
