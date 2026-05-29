# CLAUDE.md

## Project Overview

GLogo is an iOS image editing application built with Swift 6.0 and SwiftUI (iOS 17.6+).

**Architecture**: MVVM + Clean Architecture with four layers:
- **Models**: Pure data structures
- **UseCases**: All business logic (Coordinator, Service, Policy, Repository patterns)
- **ViewModels**: Presentation logic (@ObservableObject)
- **Views**: SwiftUI UI

**Dependency Rule**: Views → ViewModels → UseCases → Models (inner layers must never depend on outer layers)

## Tooling for Code Analysis

**コード解析・編集は原則 Serena MCP を使うこと**。grep/find は例外的な用途に限定する。理由：grep ベースの検索は定義行とテスト内呼び出しを混同しやすく、見落としによる手戻りが発生する。Serena は LSP ベースで構造的に正確な参照解析を行うため、最初から Serena を使う方が結果的に早い。

### セッション開始時の必須手順
1. `mcp__serena__initial_instructions` を呼んで Serena の操作マニュアルを読む
2. 以降のコード探索・編集は Serena ツールを基本にする

### 主に使う Serena ツール

| 用途 | ツール |
|------|--------|
| 新規ファイル/モジュール理解 | `mcp__serena__get_symbols_overview` |
| 関数/型の定義検索 | `mcp__serena__find_symbol` |
| 参照元の列挙（未使用判定・影響範囲確認） | `mcp__serena__find_referencing_symbols` |
| 安全なリネーム | `mcp__serena__rename_symbol` |
| 参照確認付き削除 | `mcp__serena__safe_delete_symbol` |
| シンボル本体の置換 | `mcp__serena__replace_symbol_body` |
| シンボル前後への挿入 | `mcp__serena__insert_before_symbol` / `insert_after_symbol` |

### grep/find が許容される例外
LSP の対象外であるため、以下のみ grep を使ってよい：
- 文字列リテラル / コメント / `// MARK:` の検索
- ファイル名パターンによる列挙（`find` で .swift ファイル数を数える等）
- ビルドログ / テスト出力の grep

それ以外の「この関数どこで使われている？」「未使用か確認」「参照範囲を見たい」系は **必ず Serena**。

## Build Commands

```bash
# Build
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo build

# Test
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo test

# Specific test
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo -only-testing:GLogoTests/TestClassName test
```

## Architecture Rules

### ❌ PROHIBITED
- Business logic in Views or ViewModels (must be in UseCases)
- @Published/@ObservableObject in Models
- Direct Model manipulation in Views
- UseCases depending on ViewModels or Views
- References from inner layers to outer layers

### ✅ REQUIRED
- All business logic in UseCases layer
- ViewModels delegate to UseCases for all operations
- Models are pure data structures only
- Views observe ViewModels via @ObservedObject/@StateObject
- Unidirectional data flow: View → ViewModel → UseCase → Model

### Layer Responsibilities

| Layer | Allowed | Prohibited |
|-------|---------|------------|
| **Models** | struct/class, Codable, computed properties | @Published, business logic, outer layer references |
| **UseCases** | Business logic, Coordinator/Service/Policy/Repository patterns | @Published, ViewModel/View dependencies, SwiftUI imports |
| **ViewModels** | @ObservableObject, @Published, UseCase delegation | Business logic implementation, direct Model manipulation |
| **Views** | SwiftUI, @ObservedObject/@StateObject, minimal local UI state | Business logic, direct Model access, UseCase calls |

## Coding Standards

### Documentation & Comments
- Repository source of truth: follow `AGENTS.md` for repository-wide comment/documentation rules; keep this file aligned with it.
- **All comments in Japanese** (日本語でコメントを記述)
- Prefer comments that explain `why`, constraints, compatibility, performance, concurrency, rendering assumptions, or API quirks.
- Use `///` for non-obvious contracts of types, methods, serialization rules, and only those properties whose behavior is not self-evident.
- Avoid line-by-line explanations, property-name restatements, Swift syntax explanations, debug leftovers, and generic placeholder notes.
- Keep file header summaries short and responsibility-focused.
- Use `// MARK: - <Section>` to group by responsibility. Prefer labels such as `Canvas Rendering`, `Image Import`, `Persistence Compatibility`, or `Gesture Handling` over a fixed template.

### Naming Conventions
- Variables/Properties: `camelCase`
- Types (Class/Struct/Enum): `PascalCase`
- Files: `PascalCase.swift`

### Memory Management
- Use `[weak self]` in closures
- Use `autoreleasepool` for heavy image processing
- Use `@MainActor` for UI updates

### Concurrency
- Primary: Swift Concurrency (`async/await`, `Task`, `@MainActor`)
- Heavy processing: `Task.detached` for background execution
