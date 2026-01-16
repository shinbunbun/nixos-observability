# すべてのモジュールをインポート
{ config, lib, pkgs, ... }:
{
  imports = [
    # 後でモジュールを追加していきます
    # ./monitoring.nix
    # ./alertmanager.nix
    # ./loki.nix
    # ./fluent-bit.nix
    # ./opensearch.nix
    # ./opensearch-dashboards.nix
  ];
}
