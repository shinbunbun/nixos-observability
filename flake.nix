{
  description = "NixOS Observability Stack - Node Exporter, Process Exporter, Fluent Bit";

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
      #
      # system カバレッジは x86_64-linux のみに絞る。消費側の NixOS ホスト
      # (dotfiles の homeMachine/g3pro、dotfiles-private の nixos-desktop) は
      # すべて x86_64-linux であり、aarch64-linux ターゲットは存在しない。
      # CI (.github/workflows/ci.yaml) も x86_64-linux しかビルドしないため、
      # packages 宣言を x86_64-linux のみに揃えて「宣言と CI が一致」させる。
      # 将来 aarch64-linux ホストを追加する際は、この genAttrs のリストに
      # "aarch64-linux" を戻し、CI 側にも aarch64 ビルド job を追加する。
      packages = nixpkgs.lib.genAttrs [ "x86_64-linux" ] (
        system:
        let
          # 評価に必要な最小限のシステム設定。各 validate-* パッケージで
          # 共通利用する。
          baseSystem = {
            boot.loader.grub.enable = false;
            fileSystems."/" = {
              device = "/dev/disk/by-label/nixos";
              fsType = "ext4";
            };
            system.stateVersion = "24.11";
          };

          # monitoring (nodeExporter + processExporter) を有効化する設定。
          monitoringConfig = {
            services.observability.monitoring = {
              enable = true;
              nodeExporter.enable = true;
              processExporter = {
                enable = true;
                # processNames の submodule 型を実証する代表値。
                # 既定 (name + cmdline) に加え comm / exe フィールドも
                # 受理されることを評価レベルで検証する。
                processNames = [
                  {
                    name = "{{.Comm}}";
                    cmdline = [ ".+" ];
                  }
                  {
                    name = "sshd";
                    comm = [ "sshd" ];
                  }
                  {
                    name = "node-exporter";
                    exe = [ "/run/current-system/sw/bin/node_exporter" ];
                  }
                ];
              };
            };
          };

          # fluentBit (configFile 注入) を有効化する設定。
          fluentBitConfig =
            { pkgs, ... }:
            {
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
            };

          # 指定モジュール + 設定の最小 NixOS システムを評価し toplevel を返す。
          mkValidate =
            modules:
            (nixpkgs.lib.nixosSystem {
              inherit system;
              modules = [ baseSystem ] ++ modules;
            }).config.system.build.toplevel;
        in
        {
          # モジュール評価バリデーション
          # monitoring / fluentBit の両方を import した最小 NixOS システムを
          # 評価し、その toplevel をビルドする。評価が通れば成功。
          validate-configs = mkValidate [
            self.nixosModules.monitoring
            self.nixosModules.fluentBit
            monitoringConfig
            fluentBitConfig
          ];

          # monitoring モジュール単独有効化パス。
          # fluentBit を import せず monitoring だけを評価し、
          # 片方だけ有効化したときの conditional 評価を検証する。
          validate-monitoring-only = mkValidate [
            self.nixosModules.monitoring
            monitoringConfig
          ];

          # fluentBit モジュール単独有効化パス。
          # monitoring を import せず fluentBit だけを評価し、
          # 片方だけ有効化したときの conditional 評価を検証する。
          validate-fluentbit-only = mkValidate [
            self.nixosModules.fluentBit
            fluentBitConfig
          ];
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
