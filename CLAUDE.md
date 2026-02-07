# CLAUDE.md

## Project Overview

GLogo is an iOS image editing application built with Swift 6.0 and SwiftUI (iOS 17.6+).

**Architecture**: MVVM + Clean Architecture with four layers:
- **Models**: Pure data structures
- **UseCases**: All business logic (Coordinator, Service, Policy, Repository patterns)
- **ViewModels**: Presentation logic (@ObservableObject)
- **Views**: SwiftUI UI

**Dependency Rule**: Views → ViewModels → UseCases → Models (inner layers must never depend on outer layers)

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

### Language
- **All comments in Japanese** (日本語でコメントを記述)
- Documentation: `///` (Swift DocC format)
- Implementation notes: `//`

### MARK Separation (Mandatory)
```swift
// MARK: - Properties
// MARK: - Initialization
// MARK: - Public Methods
// MARK: - Private Methods
```

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
