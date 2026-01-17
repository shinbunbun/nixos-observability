# すべてのモジュールをインポート
{ config, lib, pkgs, ... }:
{
  imports = [
    ./monitoring.nix
    ./alertmanager.nix
    # ./loki.nix                    # Phase 4で追加
    # ./fluent-bit.nix              # Phase 4で追加
    # ./opensearch.nix              # Phase 5で追加
    # ./opensearch-dashboards.nix   # Phase 5で追加
  ];
}
