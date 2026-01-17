# すべてのモジュールをインポート
{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./monitoring.nix
    ./alertmanager.nix
    ./loki.nix
    ./opensearch.nix
    ./opensearch-dashboards.nix
    ./fluent-bit.nix
  ];
}
