# NixOS Observability Stack

NixOS ホスト上で稼働する観測可能性エージェントを管理するモジュール集。
**メトリクス収集・アラート評価・ログ保存は外部スタック（k3s 上の VictoriaMetrics / Alloy 等）が担う**という
policy-free 設計を採用しており、NixOS 側はスクレイプ対象の exporter とログ転送エージェントのみを提供する。

現在提供しているモジュール:

- **monitoring** - Node Exporter (ホスト全体メトリクス) および Process Exporter (プロセス別メトリクス)
- **fluentBit** - Fluent Bit ログ収集エージェント (設定ファイルを外部から注入)

## Quick Start

### 1. `flake.nix` に追加

```nix
{
  inputs.nixos-observability = {
    url = "github:shinbunbun/nixos-observability";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

### 2. モジュールをインポート

```nix
{
  imports = [ inputs.nixos-observability.nixosModules.default ];
}
```

### 3. 基本設定

```nix
{
  services.observability = {
    # Node Exporter + Process Exporter
    # 外部の VMAgent / Victoria Metrics がこれらをスクレイプする
    monitoring = {
      enable = true;
      nodeExporter.enable = true;     # ホスト全体メトリクス (port 9100)
      processExporter.enable = true;  # プロセス別メトリクス (port 9256)
    };

    # Fluent Bit ログ転送エージェント
    # 設定ファイルは dotfiles 側から注入する (policy-free)
    fluentBit = {
      enable = true;
      configFile = ./fluent-bit.conf;
    };
  };
}
```

## Modules

### monitoring

Node Exporter と Process Exporter を管理するモジュール。

| option | 型 | デフォルト | 説明 |
|--------|----|------------|------|
| `monitoring.enable` | bool | false | モジュール全体の有効化 |
| `monitoring.nodeExporter.enable` | bool | true | Node Exporter を有効化 |
| `monitoring.nodeExporter.port` | port | 9100 | Node Exporter がリッスンするポート |
| `monitoring.nodeExporter.enabledCollectors` | list | (省略) | 有効にするコレクター一覧 |
| `monitoring.nodeExporter.extraFlags` | list | (省略) | Node Exporter への追加フラグ |
| `monitoring.processExporter.enable` | bool | false | Process Exporter を有効化 (opt-in) |
| `monitoring.processExporter.port` | port | 9256 | Process Exporter がリッスンするポート |
| `monitoring.processExporter.processNames` | list | (省略) | プロセス集約ルール (`process_names`) |
| `monitoring.openFirewall` | bool | true | 有効な exporter のポートをファイアウォールで開放 |

`nodeExporter` と `processExporter` は独立して有効化できる。
すでに Node Exporter を別途直接設定しているホストは
`nodeExporter.enable = false` として `processExporter` だけ利用可能。

### fluentBit

Fluent Bit ログ収集エージェントを管理するモジュール。

| option | 型 | デフォルト | 説明 |
|--------|----|------------|------|
| `fluentBit.enable` | bool | false | モジュール全体の有効化 |
| `fluentBit.configFile` | path | (必須) | Fluent Bit 設定ファイルのパス |
| `fluentBit.package` | package | `pkgs.fluent-bit` | 使用する Fluent Bit パッケージ |
| `fluentBit.port` | port | 2020 | HTTP メトリクス firewall ポート (openFirewall 専用、Fluent Bit 本体には渡らない。configFile の [SERVICE] HTTP_Port と一致させること) |
| `fluentBit.dataDir` | str | `/var/lib/fluent-bit` | データ保存ディレクトリ |
| `fluentBit.extraPackages` | list | [] | Fluent Bit から利用可能にする追加パッケージ |
| `fluentBit.openFirewall` | bool | false | Fluent Bit ポートをファイアウォールで開放 |
| `fluentBit.firewallPorts` | list | [] | 追加で開放する UDP/TCP ポート (syslog 等) |

設定ファイル (`configFile`) は nixos-observability 側では提供しない。
dotfiles 側で Fluent Bit ネイティブ形式の設定ファイルを用意して注入する。

## Architecture

**policy-free 設計**: このリポジトリはモジュール（ツールの起動・設定インタフェース）のみを提供し、
アラートルール・ダッシュボード・ログ処理パイプラインなどのポリシーは
`nixos-observability-config` または各ホストの dotfiles 側で注入する。

```
dotfiles (host config)
  └─ imports nixos-observability.nixosModules.default
       ├─ monitoring: Node Exporter / Process Exporter を起動
       └─ fluentBit:  設定ファイルを受け取り fluent-bit.service を起動
```

メトリクスのスクレイプ・保存・アラート評価は k3s クラスタ上の外部スタックが担う。

## License

MIT License - see [LICENSE](LICENSE) file for details.
