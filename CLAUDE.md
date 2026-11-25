# CLAUDE.md

リポジトリ共通のルール（構成、MVVM + Clean Architecture の層の責務、命名、コメント、テスト、コミット、コード探索、変更時の手順）は `AGENTS.md` を正とし、以下で取り込む。
このファイルには Claude Code 固有の補足だけを書き、`AGENTS.md` と矛盾する規則を再定義しない。ルールを変えるときは `AGENTS.md` 側を更新する。

@AGENTS.md

## Claude Code 固有の補足

### ビルド・テスト

コマンドは `AGENTS.md` の Build, Test, and Development Commands に従う。`swiftformat` が未導入の場合は、実行できなかったことを結果に明記する。

ファイルの追加・移動が多かった後に Serena の参照検索が空になる場合は、ビルドを1回実行して索引を更新し、ユーザーに `/mcp` から serena を再接続してもらう（参照検索には `xcode-build-server` と、リポジトリ直下の `buildServer.json` が必要）。

### Codex スキルの扱い

`AGENTS.md` が参照する Codex スキル（`glogo-change-planning`、`glogo-post-change-review`、`glogo-regression-shelf-review`）は Claude Code の Skill としては呼び出せない。該当する作業では `~/.codex/skills/<スキル名>/SKILL.md` を読み、同じ手順とチェックリストを手動で実施する。

### MCP ツール

- Serena・Codegraph は接続できている場合だけ使う。Serena を使う場合は最初に `mcp__serena__initial_instructions` を呼ぶ。
- 接続できない場合は、その制約を明示して `rg` とソース・テストの確認で補う（`AGENTS.md` の Tooling & Code Search に従う）。

| 用途 | Serena ツール |
|------|---------------|
| ファイル・モジュールの把握 | `mcp__serena__get_symbols_overview` |
| 定義の検索 | `mcp__serena__find_symbol` |
| 参照元の列挙（未使用判定・影響範囲） | `mcp__serena__find_referencing_symbols` |
| リネーム | `mcp__serena__rename_symbol` |
| 参照確認付き削除 | `mcp__serena__safe_delete_symbol` |
| シンボル本体の置換・前後への挿入 | `mcp__serena__replace_symbol_body` / `insert_before_symbol` / `insert_after_symbol` |
