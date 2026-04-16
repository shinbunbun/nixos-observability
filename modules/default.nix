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
    ./opensearch.nix
    ./opensearch-dashboards.nix
    ./fluent-bit.nix
  ];
}
