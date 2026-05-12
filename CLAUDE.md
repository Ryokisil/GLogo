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

正確さが要求される作業では **Serena MCP** を積極的に使用すること。LSP ベースのシンボル解析が grep/find より信頼できるため、以下のような場面で必ず Serena を利用する：

- **コードベース確認**: 関数/型の定義場所、参照範囲、影響範囲の特定
- **リファクタリング**: シンボルのリネーム、安全な削除、依存関係の追跡
- **新規機能追加**: 既存 API との整合性確認、命名衝突チェック、配置先決定
- **テスト作成**: 対象シンボルの呼び出し元・依存関係の網羅

主に使う Serena ツール：

| ツール | 用途 |
|--------|------|
| `mcp__serena__find_symbol` | 関数/型の定義検索（grep の代わり、構造を保持） |
| `mcp__serena__find_referencing_symbols` | 参照元の正確な列挙（"未使用"判定にも使う） |
| `mcp__serena__get_symbols_overview` | 新規ファイル理解時の最初の一手 |
| `mcp__serena__rename_symbol` | 安全なリネーム（参照全てを更新） |
| `mcp__serena__safe_delete_symbol` | 参照を確認しつつ削除 |

grep/find が許容されるのは、文字列リテラル検索やコメント探索など LSP の対象外の場合のみ。「呼び出し元ゼロ」判定や API 影響範囲の確認では **必ず Serena を使う**こと（grep だと定義行とテスト内呼び出しを混同しやすい）。

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
