# nixos-observability - Claude 作業ガイド

このリポジトリは NixOS ホスト向けの観測可能性モジュール集です。
グローバルな作業ルールは統合リポジトリの `.claude/CLAUDE.md` を参照してください。

## リポジトリ概要

- **提供モジュール**: `monitoring` (Node Exporter / Process Exporter)、`fluentBit` (Fluent Bit エージェント)
- **設計方針**: policy-free — アラートルール・ログパイプライン設定は外部 (nixos-observability-config / dotfiles) から注入する
- **モジュールエントリポイント**: `modules/default.nix` → `modules/monitoring.nix`, `modules/fluent-bit.nix`

## ブランチ運用

mainブランチへの直接コミットは禁止。必ずブランチを切って PR を出す。

```bash
git checkout -b feature/your-feature-name origin/main
```

## 検証手順

```bash
# validate-configs を実際に評価する (flake check は checks output が存在しないため packages を指定する)
nix build .#packages.x86_64-linux.validate-configs
```

## スコープ外

- アラートルール・Grafana ダッシュボード → `nixos-observability-config`
- Fluent Bit の具体的な設定ファイル → 各ホストの dotfiles
- Grafana / Prometheus / Alertmanager / Loki モジュール → PR #15〜#18 で削除済み、復活させない
