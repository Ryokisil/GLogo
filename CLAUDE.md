# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**⚠️ IMPORTANT: This project requires strict adherence to MVVM architecture and Japanese coding standards. All code must follow these mandatory guidelines.**

## Project Overview

GLogo is an advanced iOS image editing application built with Swift 6.0 and SwiftUI. It provides a comprehensive logo creation and editing interface with professional-grade image manipulation capabilities, featuring custom Core Image filters, event-sourcing based undo/redo system, and seamless SwiftUI + UIKit integration.

**Architecture Philosophy**: Strict MVVM pattern with clear separation between Models (data), ViewModels (business logic), and Views (UI). Deviations from this pattern are not permitted.

### Key Features
- **Professional Image Editing**: Custom highlight/shadow adjustments using ITU-R BT.709 luminance masking
- **Advanced Event Sourcing**: Complete undo/redo system with 20+ specific event types
- **Hybrid UI Architecture**: SwiftUI interface with UIKit-based high-performance canvas
- **Memory-Safe Design**: Comprehensive memory leak prevention with automated testing
- **macOS Catalyst Support**: Full desktop experience with menu commands and keyboard shortcuts

## Development Commands

### API Reference & Documentation
**Primary Sources for Implementation**:
- **Apple Developer Documentation**: Official API references and framework guides
  - Core Image: Custom filter implementation and performance optimization
  - Core Graphics: Advanced rendering and coordinate system management
  - SwiftUI + UIKit: Hybrid architecture integration patterns
  - Photos Framework: PHPhotoLibrary permission handling and asset management
- **Swift Evolution**: Language feature updates and proposals for Swift 6.0+ compliance
- **iOS Release Notes**: Version-specific API changes and deprecations
- **WWDC Session Videos**: Advanced techniques for professional app development

**Implementation Guidelines**:
- Always verify API availability for target iOS 17.6+ deployment
- Check framework compatibility across iOS versions before using new APIs
- Reference official sample code for complex integrations (Core Image, Photos access)
- Validate memory management patterns with official documentation
- Use WebFetch tool to access current Apple documentation when needed

### Build and Test
```bash
# Build the project
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo build

# Run tests
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo test

# Run specific test
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo -only-testing:GLogoTests/ImageCropTests test

# Clean build for fresh compilation
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo clean build
```

### iOS Simulator Integration
```bash
# List available simulators
xcrun simctl list devices

# Boot specific simulator
xcrun simctl boot "iPhone 15 Pro"

# Install app to simulator
xcrun simctl install booted /path/to/GLogo.app

# Launch app
xcrun simctl launch booted com.yourcompany.GLogo
```

### Xcode Project
- Open `GLogo.xcodeproj` in Xcode
- Main target: GLogo
- Test targets: GLogoTests, GLogoUITests
- Deployment target: iOS 17.6+
- Swift version: 6.0

## Architecture

### MVVM Pattern (Strict Compliance Required)
**⚠️ CRITICAL: All code MUST strictly adhere to the MVVM architecture pattern. Violations will require immediate refactoring.**

The application follows a sophisticated Model-View-ViewModel (MVVM) architecture with clear separation of concerns:

#### Architecture Rules (Mandatory)
**❌ PROHIBITED - Absolute Violations:**
- Writing business logic or data processing in Views
- Adding observable properties (@Published, ObservableObject) to Models
- Direct references from ViewModel to View
- References from Model to ViewModel or View
- Direct data modification between Views

**✅ REQUIRED - Mandatory Practices:**
- All business logic must be implemented in ViewModels
- Models must be pure data structures (struct/class only)
- Views must observe ViewModels via @ObservedObject/@StateObject
- Data flow must always be unidirectional: ViewModel → View
- User actions must be processed through ViewModel method calls

#### Models (`GLogo/Models/`)
Core data structures with comprehensive state management:
- **`LogoProject`**: Main project container with elements and settings
  - Thread-safe element collection management
  - Custom Codable implementation for CGSize and Date serialization
  - Project metadata (creation/modification timestamps, unique IDs)
- **`LogoElement`**: Abstract base class for all editable elements
  - Unified property system (position, size, rotation, opacity, visibility, lock state)
  - Hit testing and coordinate transformation support
  - Protocol-oriented design for type safety
- **Element Implementations**:
  - `TextElement`: Rich text with effects (shadow, stroke), font management, alignment
  - `ShapeElement`: Vector shapes with gradient support, custom paths, polygon generation
  - `ImageElement`: Advanced image processing with Core Image integration
- **`BackgroundSettings`**: Canvas background configuration with gradient/solid color support

#### ViewModels (`GLogo/ViewModels/`)
Business logic layer with reactive state management:
- **`EditorViewModel`**: Central coordinator
  - Project state management with @Published properties
  - Element manipulation operations (add, select, delete, transform)
  - Event sourcing integration for undo/redo
  - Real-time property updates with change detection
- **`ElementViewModel`**: Individual element manipulation
  - Property editing with validation
  - Type-specific operations (text formatting, shape geometry, image filters)
- **`ImageCropViewModel`**: Advanced cropping functionality
  - iOS orientation-aware cropping with `createOrientedCGImage`
  - Real-time preview updates

#### Views (`GLogo/Views/`)
SwiftUI interface components with UIKit integration:
- **`EditorView`**: Main editing interface with tool panels
- **`CanvasView`**: High-performance UIKit canvas integrated via UIViewRepresentable
- **Tool Panels**: Modular property editors for each element type
- **Utility Views**: Image picker, crop overlay, export options

#### Application Entry Point
- **`GameLogoMakerApp`**: SwiftUI App lifecycle with WindowGroup
  - macOS Catalyst support with menu commands and keyboard shortcuts
  - Global settings management through `AppSettings` class
  - Notification-based communication for cross-component messaging

### Event Sourcing System
The application implements a comprehensive event sourcing pattern for reliable undo/redo functionality:

#### Core Architecture
- **`EditorEvent` Protocol**: Base interface for all state changes
  - `apply(to:)` and `revert(from:)` methods for bidirectional operations
  - Timestamp tracking and event naming for debugging
  - Full Codable support for persistence
- **`EditorHistory` Class**: Event stack management
  - Dual stack architecture (undo/redo stacks)
  - Maximum history limit with automatic cleanup
  - Memory-safe weak references to prevent retain cycles

#### Event Type Hierarchy (20+ Specific Events)
**Element Lifecycle Events:**
- `ElementAddedEvent`, `ElementRemovedEvent`: Basic element operations
- `ElementTransformedEvent`: Composite operations (move + resize + rotation)

**Text Element Events:**
- `TextContentChangedEvent`: Text content modifications
- `TextColorChangedEvent`: Color changes with custom UIColor encoding
- `FontChangedEvent`: Font family and size updates

**Shape Element Events:**
- `ShapeTypeChangedEvent`: Geometry type changes (rectangle, circle, polygon, etc.)
- `ShapeFillColorChangedEvent`, `ShapeStrokeColorChangedEvent`: Color management
- `ShapeFillModeChangedEvent`: Fill type (solid, gradient, none)
- `ShapeGradientColorsChangedEvent`, `ShapeGradientAngleChangedEvent`: Gradient properties

**Image Element Events:**
- `ImageFitModeChangedEvent`: Aspect ratio handling
- `ImageSaturationChangedEvent`, `ImageBrightnessChangedEvent`, `ImageContrastChangedEvent`: Basic adjustments
- `ImageHighlightsChangedEvent`, `ImageShadowsChangedEvent`: Advanced selective adjustments
- `ImageTintColorChangedEvent`: Color overlay effects
- `ImageFrameColorChangedEvent`, `ImageRoundedCornersChangedEvent`: Visual styling

**Project-Level Events:**
- `ProjectNameChangedEvent`, `CanvasSizeChangedEvent`: Project metadata
- `BackgroundSettingsChangedEvent`: Canvas background configuration

#### Technical Implementation Details
**UIColor Serialization:**
```swift
// Custom encoding for color persistence
private enum CodingKeys: String, CodingKey {
    case timestamp, elementId, oldColorData, newColorData
}

func encode(to encoder: Encoder) throws {
    let colorData = try NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false)
    try container.encode(colorData, forKey: .colorData)
}
```

**Memory Management:**
- Events hold minimal data (IDs, values) rather than object references
- Automatic cleanup of old events beyond history limit
- Weak references in callback patterns to prevent memory leaks

### SwiftUI + UIKit Integration Architecture
The application employs a sophisticated hybrid approach combining SwiftUI's declarative UI with UIKit's performance-critical canvas rendering:

#### Core Integration Pattern
**UIViewRepresentable Bridge (`CanvasViewRepresentable`):**
- Seamless integration between SwiftUI and UIKit through `CanvasViewRepresentable`
- Coordinator pattern implementation for delegate-style communication
- Real-time state synchronization between SwiftUI `@ObservedObject` and UIKit views

#### High-Performance Canvas (`CanvasView`)
**UIKit-Based Drawing Engine:**
```swift
class CanvasView: UIView {
    // Direct Core Graphics rendering for optimal performance
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        // Custom drawing pipeline with coordinate transformation
    }
}
```

**Advanced Gesture Handling:**
- Multi-touch gesture recognition (pinch zoom, pan, tap, double-tap)
- Complex manipulation detection (move, resize, rotate) with visual feedback
- Handle-based element editing with pixel-perfect hit testing
- Grid snapping and visual guides for precise positioning

**Coordinate System Management:**
- Dual coordinate system support (display vs. canvas coordinates)
- Affine transformation matrix for zoom and pan operations
- Real-time coordinate conversion with `convertPointToCanvas/_FromCanvas`

#### Communication Architecture
**Callback-Based Event System:**
```swift
// Type-safe callback closures for UIKit → SwiftUI communication
var onElementSelected: ((LogoElement?) -> Void)?
var onManipulationStarted: ((ElementManipulationType, CGPoint) -> Void)?
var onManipulationChanged: ((CGPoint) -> Void)?
```

**Notification Center Integration:**
- Cross-component communication for complex operations
- Camera positioning updates via `"CenterCameraOnPoint"` notifications
- Keyboard shortcut handling and menu command routing

#### Performance Optimizations
**Selective Redrawing:**
- Strategic `setNeedsDisplay()` calls to minimize unnecessary redraws
- View state caching for smooth interaction during transformations
- Efficient gesture state management to prevent redundant operations

**Memory Management:**
- Weak reference patterns in coordinator callbacks
- Automatic cleanup of gesture recognizers and notification observers
- Optimized view hierarchy to prevent retain cycles

### Core Graphics Integration
Advanced rendering pipeline using Core Graphics and Core Image:
- `CanvasRenderer.swift`: High-quality export rendering with custom resolution scaling
- `ElementRenderer.swift`: Individual element rendering with effects and transformations
- `ImageFilterUtility.swift`: Custom Core Image filter implementations for professional image adjustments

## Advanced Image Processing Implementation

### Professional-Grade Color Adjustments
The application implements sophisticated image processing techniques that exceed standard Core Image capabilities:

#### Custom Highlight/Shadow Adjustment Algorithm
**Problem Solved**: Core Image lacks dedicated highlight/shadow filters, requiring custom implementation for professional-grade selective adjustments.

**Technical Implementation**:
```swift
// Luminance-based masking using ITU-R BT.709 standard
static func applyHighlightAdjustment(to image: CIImage, amount: CGFloat) -> CIImage? {
    // RGB→Luminance conversion with industry-standard coefficients
    luminanceFilter.setValue(CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0), forKey: "inputRVector")
    
    // Multi-pass processing pipeline:
    // 1. Extract luminance mask
    // 2. Apply gamma correction for enhanced masking
    // 3. Selective exposure adjustment
    // 4. Masked blending with original
}
```

**Key Features**:
- **ITU-R BT.709 Coefficients**: Industry-standard luminance calculation (R: 0.2126, G: 0.7152, B: 0.0722)
- **Selective Processing**: Only affects intended tonal ranges (highlights vs shadows)
- **Natural Results**: Maintains color relationships and prevents artificial appearance
- **Performance Optimized**: Early return for zero adjustments, clamped input ranges

#### Multi-Pass Filter Architecture
**Highlight Processing Pipeline**:
1. **Luminance Extraction**: Convert RGB to grayscale using perceptual weighting
2. **Gamma Masking**: Enhance bright regions with gamma adjustment (0.5 for highlights)
3. **Exposure Modification**: Apply positive/negative EV adjustments
4. **Masked Composition**: Blend original and adjusted images using luminance mask

**Shadow Processing Pipeline**:
1. **Inverted Masking**: Create mask emphasizing dark regions
2. **Contrast Enhancement**: Selective contrast adjustments for shadow detail
3. **Brightness Lifting**: Careful exposure increases without clipping
4. **Natural Blending**: Preserve overall image balance

### iOS Image Orientation Resolution
**Critical Issue Addressed**: iOS image coordinate system mismatch between UIImage and CGImage causing incorrect crop operations.

#### Technical Problem Analysis
```swift
// Problem: Coordinate system mismatch
UIImage.size = (width: 1178, height: 1572)  // Display orientation
CGImage.size = (width: 1572, height: 1178)  // Physical pixel array
```

#### Solution Implementation
```swift
private func createOrientedCGImage(from uiImage: UIImage) -> CGImage? {
    let size = uiImage.size
    let format = UIGraphicsImageRendererFormat()
    format.scale = uiImage.scale  // Maintain Retina support
    format.opaque = false         // Preserve transparency
    
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    let renderedImage = renderer.image { context in
        // Automatic orientation correction during rendering
        uiImage.draw(in: CGRect(origin: .zero, size: size))
    }
    return renderedImage.cgImage
}
```

**Benefits**:
- **Coordinate Consistency**: Eliminates size/coordinate mismatches
- **Retina Support**: Maintains scale factor for high-DPI displays
- **Transparency Preservation**: Supports PNG alpha channels
- **Universal Compatibility**: Works with all iOS image orientations

### Memory-Efficient Processing
**Optimization Strategies**:
- **Lazy Evaluation**: Filters applied only when needed
- **Result Caching**: `cachedImage` and `cachedOriginalImage` properties
- **Autoreleasepool Usage**: Memory cleanup for intensive operations
- **Early Returns**: Skip processing for identity operations

## Comprehensive Testing Strategy

### Testing Infrastructure
The application includes comprehensive test coverage:

#### Available Test Suites
- **`GLogoTests`**: General unit tests for core functionality
- **`ImageCropTests`**: Image cropping functionality validation
- **`ToneCurveFilterTests`**: Tone curve filter implementation tests

#### Memory Management Best Practices
**Weak Reference Management**:
- Coordinator pattern callbacks use `[weak self]` capture lists
- ViewModel cross-references avoid retain cycles
- Event system uses minimal object references (IDs over direct references)

**Autoreleasepool Strategy**:
```swift
autoreleasepool {
    // Memory-intensive image processing operations
    let processedImage = applyComplexFilters(to: originalImage)
    return processedImage
}
```

### Test Execution Commands
```bash
# Comprehensive test suite
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo test \
  -resultBundlePath TestResults.xcresult

# Run specific test class
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo \
  -only-testing:GLogoTests/ImageCropTests test
```

### Performance Testing Considerations
**Areas Requiring Monitoring**:
- Large image processing operations
- Complex undo/redo history management
- Multi-element selection and manipulation
- Real-time canvas rendering during interactions

## Code Quality & Performance Optimization

### Swift 6.0 Modern Language Features
**Strict Concurrency Compliance**:
- Full adoption of Swift 6.0's enhanced concurrency model
- Sendable protocol conformance for thread-safe data sharing
- Actor-based isolation where appropriate for state management
- Compile-time verification of data race prevention

### Protocol-Oriented Design
**Type Safety & Extensibility**:
```swift
// Base protocol for all editable elements
protocol LogoElement: Codable {
    var id: UUID { get }
    var type: LogoElementType { get }
    func copy() -> LogoElement
    func hitTest(_ point: CGPoint) -> Bool
    func draw(in context: CGContext)
}
```

**Benefits**:
- **Runtime Safety**: Compile-time type checking prevents casting errors
- **Extensibility**: New element types easily added without breaking existing code
- **Testability**: Protocol-based mocking for comprehensive unit testing

### Enumeration-Based State Management
**Type-Safe State Representation**:
```swift
enum EditorMode {
    case select, textCreate, shapeCreate, imageImport, delete
}

enum ImageFitMode: String, Codable {
    case fill, aspectFit, aspectFill, center, tile
}
```

### Performance Optimization Strategies

#### Rendering Performance
**Selective Redraw Optimization**:
- Strategic `setNeedsDisplay()` calls minimize unnecessary redraws
- Cached image management prevents redundant filter applications
- Coordinate transformation caching for smooth zoom/pan operations

**Memory Efficiency**:
```swift
// Efficient memory management for large images
autoreleasepool {
    let processedImage = ImageFilterUtility.applyFilters(to: originalImage)
    self.cachedImage = processedImage
}
```

#### Event System Performance
**Minimal Object References**:
- Events store IDs rather than object references
- Lazy evaluation of event descriptions
- Automatic cleanup of history beyond configurable limits

## Coding Standards & Conventions

### Comment Guidelines
**Documentation Comments (`///`)**:
```swift
/// エディタの主要な状態を管理するビューモデル
/// ユーザーの編集操作を受け取り、プロジェクトの状態を更新する
class EditorViewModel: ObservableObject {
    
    /// 現在編集中のプロジェクト
    @Published private(set) var project: LogoProject
    
    /// 選択中の要素（nilの場合は未選択）
    @Published private(set) var selectedElement: LogoElement?
    
    /// プロジェクトに新しい要素を追加する
    /// - Parameter element: 追加する要素
    func addElement(_ element: LogoElement) {
        // Implementation...
    }
}
```

**Inline Comments (`//`)**:
```swift
func processImage(_ image: UIImage) -> UIImage? {
    // 画像の向きを正規化して座標系の不整合を防ぐ
    guard let orientedCGImage = createOrientedCGImage(from: image) else {
        return nil
    }
    
    // フィルターチェーンを適用
    let filteredImage = applyFilters(to: orientedCGImage)
    
    return UIImage(cgImage: filteredImage)
}
```

### Language & Documentation
**Primary Language**: Japanese for all comments and documentation
- **Rationale**: プロジェクトの主要開発者が日本語話者のため、実装意図と技術的判断を正確に伝達
- **API Documentation**: `///` を使用してSwift DocCの形式に準拠
- **Implementation Notes**: `//` を使用して実装詳細や注意点を記載

### Code Organization with MARK
**Mandatory Section Separation**:
```swift
class EditorViewModel: ObservableObject {
    // MARK: - Properties
    
    @Published private(set) var project: LogoProject
    @Published private(set) var selectedElement: LogoElement?
    
    // MARK: - Initialization
    
    init(project: LogoProject = LogoProject()) {
        self.project = project
    }
    
    // MARK: - Element Operations
    
    func addElement(_ element: LogoElement) {
        // Implementation...
    }
    
    func deleteSelectedElement() {
        // Implementation...
    }
    
    // MARK: - Private Methods
    
    private func updateProjectState() {
        // Implementation...
    }
}
```

**Standard MARK Categories**:
- `// MARK: - Properties`: All properties and constants
- `// MARK: - Initialization`: Initializers and setup methods
- `// MARK: - Public Methods`: Public interface methods
- `// MARK: - Private Methods`: Internal implementation methods
- `// MARK: - Event Handling`: User interaction and callback methods
- `// MARK: - Protocol Conformance`: Protocol implementation groups

### Concurrency Standards
**Swift Concurrency Usage**:
```swift
/// 画像処理を非同期で実行する
/// - Parameter image: 処理対象の画像
/// - Returns: 処理済みの画像
@MainActor
func processImageAsync(_ image: UIImage) async -> UIImage? {
    // UIKit操作は@MainActorで実行
    let size = image.size
    
    // 重い処理は非同期タスクで実行
    return await withTaskGroup(of: UIImage?.self) { group in
        group.addTask {
            // Core Image処理（バックグラウンドスレッド）
            return await self.applyFiltersAsync(to: image)
        }
        
        return await group.first { $0 != nil } ?? image
    }
}
```

**Concurrency Guidelines**:
- **Primary Pattern**: Swift Concurrency (`async/await`, `Task`, `@MainActor`)
- **Legacy Support**: 必要な場合のみGCD使用（外部ライブラリとの互換性等）
- **UI Updates**: `@MainActor` アノテーションで確実にメインスレッド実行
- **Heavy Processing**: `Task.detached` でバックグラウンド実行

### Naming Conventions
**Variables & Properties**:
```swift
// camelCase for properties and variables
var selectedElement: LogoElement?
var isProjectModified: Bool = false
var backgroundSettings: BackgroundSettings
```

**Classes & Structs**:
```swift
// PascalCase for types
class EditorViewModel: ObservableObject { }
struct LogoProject: Codable { }
enum EditorMode { }
```

**Methods**:
```swift
// Descriptive verb-based naming with Japanese documentation
/// 要素を選択状態にする
func selectElement(_ element: LogoElement)

/// プロジェクトを保存する
func saveProject(completion: @escaping (Bool) -> Void)
```

**Files**:
```swift
// PascalCase with descriptive purpose
EditorViewModel.swift          // Main editor business logic
EventSourcing.swift           // Event system implementation
ImageFilterUtility.swift     // Image processing utilities
```

### Code Structure Principles (Strict Enforcement)
**Clear Separation of Concerns - These principles must be strictly followed:**

**Models (GLogo/Models/)**:
- ✅ Allowed: Pure data structures using struct/class
- ✅ Allowed: Codable conformance, computed properties, helper methods (data transformation only)
- ❌ Prohibited: @Published, ObservableObject, business logic
- ❌ Prohibited: References to View or ViewModel

**ViewModels (GLogo/ViewModels/)**:
- ✅ Allowed: ObservableObject conformance, @Published properties
- ✅ Allowed: All business logic and state management
- ✅ Allowed: Model manipulation and data transformation
- ❌ Prohibited: Direct references to Views (callbacks/closures are acceptable)
- ❌ Prohibited: Direct UI component manipulation

**Views (GLogo/Views/)**:
- ✅ Allowed: Declarative UI using SwiftUI
- ✅ Allowed: Observing ViewModels via @ObservedObject/@StateObject
- ✅ Allowed: Forwarding user actions to ViewModel method calls
- ❌ Prohibited: Business logic implementation
- ❌ Prohibited: Direct Model manipulation
- ❌ Prohibited: Complex data processing

**Utilities (GLogo/Utils/)**:
- ✅ Allowed: Pure functions (image processing, coordinate calculations, etc.)
- ✅ Allowed: Static methods, extensions
- ❌ Prohibited: State retention, dependencies on View or ViewModel

**File Header Standard**:
```swift
//
//  EditorViewModel.swift
//  GLogo
//
//  概要:
//  このファイルはエディタ画面の主要なビューモデルを定義しています。
//  プロジェクトの状態管理、要素の追加/選択/編集/削除などの編集操作を提供し、
//  イベントソーシングシステムと連携してアンドゥ/リドゥ機能を実現します。
//

import Foundation
import UIKit
```

### Error Handling Patterns
**Consistent Error Management**:
```swift
/// 画像ファイルを読み込む
/// - Parameter url: 画像ファイルのURL
/// - Returns: 読み込んだ画像、失敗時はnil
func loadImage(from url: URL) -> UIImage? {
    do {
        let data = try Data(contentsOf: url)
        return UIImage(data: data)
    } catch {
        print("DEBUG: 画像読み込みエラー: \(error.localizedDescription)")
        return nil
    }
}
```

### Code Review Requirements (Mandatory Checklist)
**All code must meet the following criteria:**

#### Architecture Compliance
- [ ] Fully adheres to MVVM pattern
- [ ] Models contain no business logic
- [ ] Views contain no data processing
- [ ] ViewModels appropriately handle their responsibilities

#### Coding Standards
- [ ] All comments are written in Japanese
- [ ] MARK section separation is properly implemented
- [ ] Naming conventions (camelCase/PascalCase) are followed
- [ ] File headers follow the standard format

#### Memory Management
- [ ] [weak self] is appropriately used in closures
- [ ] No potential retain cycles exist
- [ ] autoreleasepool is used for heavy processing

#### Concurrency
- [ ] @MainActor is used where necessary
- [ ] async/await is properly implemented
- [ ] No potential data races exist

**❌ Code modifications required in the following cases:**
- MVVM pattern violations found → **Immediate refactoring required**
- English comments used → **Must be changed to Japanese**
- Missing MARK separation → **Must be added**
- Potential memory leaks → **Must be fixed**

## Advanced Development Workflows

### Performance Profiling
```bash
# Profile app launch performance
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -enableCodeCoverage YES build

# Memory usage analysis
xcrun simctl spawn booted log stream --predicate 'subsystem contains "GLogo"'

# Core Image filter performance testing
instruments -t "Core Image" -D trace_results.trace GLogo.app
```

### Code Quality Tools
```bash
# Swift format validation
swiftformat GLogo/ --lint

# Static analysis
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo \
  analyze -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Code coverage analysis
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo \
  -enableCodeCoverage YES test
```

### Memory Debugging
```bash
# Detailed memory leak detection with Address Sanitizer
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo \
  test -enableAddressSanitizer YES

# Memory analysis with Instruments
instruments -t "Leaks" -D leak_trace.trace GLogo.app
```

## Troubleshooting Guide

### Common Development Issues

#### Build Errors
**Swift 6.0 Concurrency Issues**:
```bash
# Problem: Sendable protocol warnings
# Solution: Add @MainActor to UI-related classes
@MainActor class EditorViewModel: ObservableObject { ... }
```

**Core Image Filter Failures**:
```swift
// Problem: Filter creation returns nil
guard let filter = CIFilter(name: "CIColorControls") else {
    print("Filter not available on this device")
    return originalImage  // Fallback to original
}
```

#### Memory Issues
**Large Image Processing**:
```swift
// Problem: Memory spikes during image processing
// Solution: Use autoreleasepool for batch operations
autoreleasepool {
    for image in imageSet {
        let processed = applyFilters(to: image)
        results.append(processed)
    }
}
```

**ViewModel Retain Cycles**:
```swift
// Problem: ViewModels not deallocating
// Solution: Use weak references in closures
onElementSelected = { [weak self] element in
    self?.handleSelection(element)
}
```

#### Performance Issues
**Canvas Rendering Lag**:
- **Symptoms**: Slow response during element manipulation
- **Diagnosis**: Check for excessive `setNeedsDisplay()` calls
- **Solution**: Implement drawing state caching

**Event History Memory Growth**:
- **Symptoms**: Memory usage increases over time
- **Diagnosis**: Event stack not clearing old entries
- **Solution**: Verify `maxHistoryCount` implementation

### Debugging Workflows

#### Core Image Filter Debugging
```bash
# Enable Core Image debug logging
export CI_PRINT_TREE=1
export CI_LOG_LEVEL=1

# Run app with filter logging
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  run
```

#### Memory Analysis
```bash
# Detailed memory allocation tracking
instruments -t "Allocations" -D memory_trace.trace GLogo.app

# Leak detection with detailed stack traces
instruments -t "Leaks" -D leak_trace.trace GLogo.app
```

#### Event System Debugging
```swift
// Add to EditorViewModel for event debugging
#if DEBUG
func printHistoryStatus() {
    print("===== Event History Debug =====")
    print("Undo stack: \(history.undoCount) events")
    print("Redo stack: \(history.redoCount) events")
    for (index, event) in history.eventStack.enumerated() {
        print("Event[\(index)]: \(event.eventName) at \(event.timestamp)")
    }
    print("===============================")
}
#endif
```

### Performance Optimization Checklist

#### Image Processing Performance
- [ ] Verify filter chain efficiency (minimize intermediate images)
- [ ] Check for unnecessary format conversions
- [ ] Implement result caching for repeated operations
- [ ] Use appropriate image scales for preview vs. export

#### UI Responsiveness
- [ ] Confirm main thread usage for UI updates
- [ ] Verify gesture handling doesn't block drawing
- [ ] Check for retain cycles in callback closures
- [ ] Optimize coordinate transformation calculations

#### Memory Management
- [ ] Use Instruments to profile memory usage regularly
- [ ] Monitor autoreleasepool usage in image processing
- [ ] Verify weak reference patterns in event system
- [ ] Check for proper cleanup in view controllers
- [ ] Enable Address Sanitizer during development testing

### Best Practices Summary

**🔴 CRITICAL - Absolute Principles (Never Compromise):**
1. **Strictly adhere to MVVM pattern** - Architecture violations require immediate refactoring
2. **Use Japanese comments** - All comments must be written in Japanese
3. **Separate sections with MARK** - Mandatory for all files

**🟡 IMPORTANT - Essential Implementation Guidelines:**
4. **Profile memory usage** regularly using Instruments and Address Sanitizer
5. **Use autoreleasepool** for memory-intensive operations
6. **Implement weak references** in callback patterns
7. **Cache expensive calculations** (coordinate transformations, filter results)
8. **Validate Core Image filter availability** before use
9. **Profile performance regularly** during development
10. **Follow Swift 6.0 concurrency guidelines** strictly