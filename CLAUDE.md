# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**⚠️ IMPORTANT: This project requires strict adherence to MVVM + Clean Architecture and Japanese coding standards. All code must follow these mandatory guidelines.**

## Project Overview

GLogo is an advanced iOS image editing application built with Swift 6.0 and SwiftUI. It provides a comprehensive logo creation and editing interface with professional-grade image manipulation capabilities, featuring custom Core Image filters, event-sourcing based undo/redo system, and seamless SwiftUI + UIKit integration.

**Architecture Philosophy**: Strict MVVM + Clean Architecture pattern with clear separation across four layers:
- **Models (Domain/Entities)**: Pure data structures representing domain concepts
- **UseCases (Business Logic)**: All application business rules, using Coordinator, Service, Policy, and Repository patterns
- **ViewModels (Presentation)**: Interface adapters that transform UseCase outputs for Views
- **Views (UI)**: SwiftUI declarative UI with minimal logic

**Dependency Rule**: All dependencies must point inward (Views → ViewModels → UseCases → Models). Inner layers must never depend on outer layers. Deviations from this pattern are not permitted.

### Key Features
- **Clean Architecture Implementation**: MVVM + Clean Architecture with four distinct layers (Models, UseCases, ViewModels, Views)
- **Professional Image Editing**: Custom highlight/shadow adjustments using ITU-R BT.709 luminance masking
- **Advanced Event Sourcing**: Complete undo/redo system with 20+ specific event types (UseCases/History)
- **Modular Business Logic**: Coordinator, Service, Policy, and Repository patterns in UseCases layer
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

### MVVM + Clean Architecture (Strict Compliance Required)
**⚠️ CRITICAL: All code MUST strictly adhere to the MVVM + Clean Architecture pattern. Violations will require immediate refactoring.**

The application follows a sophisticated MVVM + Clean Architecture pattern with clear separation of concerns across multiple layers:

#### Clean Architecture Layers
The application consists of four distinct layers following Clean Architecture principles:

```
┌─────────────────────────────────────────┐
│         Views (UI Layer)                │  SwiftUI Views
├─────────────────────────────────────────┤
│      ViewModels (Presentation)          │  @ObservableObject + @Published
├─────────────────────────────────────────┤
│    UseCases (Business Logic)            │  Coordinators, Services, Policies
│    Repositories (Data Access)           │  Abstract data access layer
├─────────────────────────────────────────┤
│      Models (Domain/Entities)           │  Pure data structures
└─────────────────────────────────────────┘
```

**Dependency Rule**: Dependencies must only point inward:
- Views → ViewModels → UseCases → Models
- ViewModels → Repositories → Models
- UseCases can depend on Repositories
- Inner layers must never know about outer layers

#### Architecture Rules (Mandatory)
**❌ PROHIBITED - Absolute Violations:**
- Writing business logic or data processing in Views
- Adding observable properties (@Published, ObservableObject) to Models
- Direct references from ViewModel to View
- References from Model to ViewModel, UseCase, or View
- Direct data modification between Views
- Business logic implementation in ViewModels (must delegate to UseCases)
- Direct Model manipulation in Views
- UseCases depending on ViewModels or Views

**✅ REQUIRED - Mandatory Practices:**
- All business logic must be implemented in UseCases layer
- ViewModels must delegate to UseCases for all business operations
- Models must be pure data structures (struct/class only)
- Views must observe ViewModels via @ObservedObject/@StateObject
- Data flow must always be unidirectional: View → ViewModel → UseCase → Model
- User actions must be processed through ViewModel → UseCase method calls
- Repositories must abstract all data access operations
- UseCases must be framework-agnostic (no UIKit/SwiftUI dependencies when possible)

#### Layer 1: Models - Domain/Entities (`GLogo/Models/`)
Pure data structures representing the core domain concepts:
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
- **`CropModels`**: Crop-related data structures
- **Supporting Models**: State models for specific features (ManualBackgroundRemovalModel, etc.)

**Design Principles**:
- No dependencies on outer layers
- Framework-agnostic (UIKit dependencies only when necessary for image/graphics types)
- Immutable when possible, with clear mutation points
- Full Codable support for persistence

#### Layer 2: UseCases - Application Business Rules (`GLogo/UseCases/`)
Business logic layer implementing all application use cases. This layer is organized by feature domain:

**`UseCases/BackgroundRemoval/`**:
- **`BackgroundRemovalUseCase`**: AI-powered background removal using Vision framework
  - High-resolution mask generation with ITU-R BT.709 luminance-based processing
  - Multi-pass filter pipeline (luminance extraction → gamma masking → feathered blending)
- **`ManualBackgroundRemovalUseCase`**: Manual brush-based background removal
  - Brush stroke rendering with adjustable size and mode (erase/restore)
  - Undo/redo support with state management

**`UseCases/Import/`**:
- **`ImageImportCoordinator`**: Orchestrates the complete image import workflow
  - Combines multiple services for end-to-end import processing
- **`ImageImportUseCase`**: Core image import business logic
  - Element creation from various sources (PHAsset, UIImage, file URL)
- **`ImageImportElementBuilder`**: Constructs ImageElement from import sources
- **`ImageImportPlacementCalculator`**: Calculates optimal element positioning
- **Supporting Types**: `ImageImportSource`, `ImageImportContext`, `ImageImportResult`

**`UseCases/SaveImage/`**:
- **`SaveImageCoordinator`**: Orchestrates the complete save workflow
  - Automatic mode detection (individual vs composite)
  - Permission handling and error recovery
- **`ImageProcessingService`**: Applies filters and creates composite images
  - Filter chain application with memory optimization
  - Multi-layer composition with proper alpha blending
- **`ImageSelectionService`**: Selects appropriate image elements for saving
  - Highest resolution selection for individual mode
  - Base image selection for composite mode
- **`PhotoLibraryWriter`**: Writes images to photo library with proper permissions
- **`SaveImagePolicy`**: Determines save mode based on project state
- **Supporting Types**: `SaveImageFormat`, `SaveImageMode`

**`UseCases/Crop/`**:
- **`CropHandleInteraction`**: Handles crop handle manipulation logic
  - Hit testing and drag calculation for crop boundaries

**`UseCases/History/`**:
- **`EventSourcing.swift`**: Complete event sourcing system
  - `EditorEvent` protocol with 20+ event types
  - `EditorHistory` class managing undo/redo stacks
  - Memory-safe event storage with automatic cleanup

**`UseCases/Rendering/`**:
- **`CanvasRenderer`**: High-quality canvas rendering for export
  - Multi-element composition with coordinate transformation
  - Custom resolution scaling for export quality
- **`ImageFilterUtility`**: Core Image filter implementations
  - Custom highlight/shadow adjustments using ITU-R BT.709 coefficients
  - Professional-grade color adjustments (saturation, brightness, contrast)
- **`FilterPipeline`**: Filter chain management and optimization
- **`ImagePreviewService`**: Optimized preview generation
- **`PreviewCache`**: Memory-efficient preview caching
- **`RenderScheduler`**: Manages rendering task scheduling
- **`RenderPolicy`**: Determines rendering strategies
- **`ToneCurveFilter`**: Tone curve adjustment implementation
- **`ToneCurveStage`**: Multi-stage tone curve processing
- **`AdjustmentStages`**: Individual adjustment stage implementations
- **`MonotonicCubicInterpolator`**: Smooth curve interpolation
- **`CIFilterInspector`**: Core Image filter inspection utilities

**`UseCases/Storage/`**:
- **`ImageAssetRepository`** (Repository Pattern): Abstracts image and proxy resolution
  - Lazy loading of high-resolution images
  - Proxy image generation for memory efficiency
  - Multi-source image resolution (asset manager, file system, in-memory)
- **`AssetManager`**: Manages image asset lifecycle
  - Disk-based asset storage and retrieval
  - Proxy image caching for performance
- **`ProjectStorage`**: Project persistence and loading
  - JSON-based project serialization
  - File system management
- **`ImageMetadataManager`**: Manages image metadata and associations

**Design Patterns in UseCases Layer**:
- **Coordinator Pattern**: Orchestrates complex workflows combining multiple services
  - Example: `SaveImageCoordinator`, `ImageImportCoordinator`
- **Service Pattern**: Single-responsibility business operations
  - Example: `ImageProcessingService`, `ImageSelectionService`
- **Policy Pattern**: Business rule evaluation and decision-making
  - Example: `SaveImagePolicy`, `RenderPolicy`
- **Repository Pattern**: Abstract data access and persistence
  - Example: `ImageAssetRepository`
- **Strategy Pattern**: Interchangeable algorithm implementations
  - Example: Filter stages, rendering strategies

**UseCase Design Principles**:
- Framework-agnostic when possible (UIKit/SwiftUI imports only when necessary)
- Single Responsibility Principle (each UseCase handles one specific business capability)
- Dependency Injection for testability
- Stateless when possible (state managed in ViewModels or passed as parameters)
- Clear error handling with typed errors

#### Layer 3: ViewModels - Interface Adapters (`GLogo/ViewModels/`)
Presentation logic layer that adapts UseCases for Views:
- **`EditorViewModel`**: Main editor coordinator
  - Delegates business logic to UseCases (SaveImageCoordinator, ImageImportCoordinator)
  - Manages presentation state with @Published properties
  - Coordinates event sourcing for undo/redo via EditorHistory UseCase
  - Transforms domain models into view-ready state
- **`ElementViewModel`**: Individual element property editing
  - Delegates transformations to appropriate UseCases
  - Manages element-specific UI state
- **`ImageCropViewModel`**: Crop interface management
  - Delegates crop calculations to CropHandleInteraction UseCase
  - Manages crop overlay state and user interactions
  - iOS orientation-aware cropping with `createOrientedCGImage`
- **`ManualBackgroundRemovalViewModel`**: Manual background removal interface
  - Delegates brush operations to ManualBackgroundRemovalUseCase
  - Manages brush state and preview updates
  - Handles undo/redo for brush strokes

**ViewModel Design Principles**:
- ObservableObject conformance with @Published properties
- Delegates all business logic to UseCases
- No direct Model manipulation (only through UseCases)
- Transforms UseCase results into view-ready state
- Manages only presentation state (not business state)
- Uses dependency injection for UseCases (enables testing)

#### Layer 4: Views - UI Layer (`GLogo/Views/`)
SwiftUI interface components with minimal logic (delegates to ViewModels):

**`Views/Editor/`**:
- **`EditorView`**: Main editing interface with tool panels
  - Observes EditorViewModel for state changes
  - Forwards user actions to ViewModel methods
- **`CanvasView`**: High-performance UIKit canvas integrated via UIViewRepresentable
  - Direct Core Graphics rendering for optimal performance
  - Gesture handling and coordinate transformation
  - Bridges UIKit rendering with SwiftUI state management
- **`ManualBackgroundRemovalView`**: Manual background removal interface
  - Observes ManualBackgroundRemovalViewModel
  - Brush stroke visualization and interaction

**`Views/ToolPanels/`**:
- Modular property editors for each element type
- Pure presentation logic (no business logic)
- Two-way binding with ViewModel @Published properties

**`Views/Components/`**:
- Reusable UI components
- Stateless when possible, or minimal local UI state

**`Views/Library/`**:
- Image library and asset management UI

**`Views/Settings/`**:
- Application settings interface

**View Design Principles**:
- Declarative UI using SwiftUI
- Observes ViewModels via @ObservedObject/@StateObject
- Forwards user actions to ViewModel methods (no business logic)
- No direct Model access (only through ViewModel)
- Minimal local state (only UI-specific state like animation flags)
- UIKit integration via UIViewRepresentable when needed for performance

#### Application Entry Point (`GLogo/App/`)
- **`GameLogoMakerApp`**: SwiftUI App lifecycle with WindowGroup
  - macOS Catalyst support with menu commands and keyboard shortcuts
  - Global settings management through `AppSettings` class
  - Notification-based communication for cross-component messaging
  - Dependency injection setup for main ViewModels

### Event Sourcing System (UseCases/History/)
The application implements a comprehensive event sourcing pattern for reliable undo/redo functionality. This system resides in the UseCases layer and provides a framework-agnostic undo/redo implementation:

#### Core Architecture
- **`EditorEvent` Protocol**: Base interface for all state changes
  - `apply(to:)` and `revert(from:)` methods for bidirectional operations
  - Timestamp tracking and event naming for debugging
  - Full Codable support for persistence
- **`EditorHistory` Class**: Event stack management UseCase
  - Dual stack architecture (undo/redo stacks)
  - Maximum history limit with automatic cleanup
  - Memory-safe weak references to prevent retain cycles
  - Framework-agnostic design (operates on Models only)

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

### Advanced Image Processing & Rendering (UseCases/Rendering/)
The rendering and image processing capabilities are implemented in the UseCases layer, providing sophisticated image manipulation that exceeds standard Core Image capabilities:

#### Core Graphics Integration
Advanced rendering pipeline using Core Graphics and Core Image:
- **`CanvasRenderer`**: High-quality export rendering with custom resolution scaling
  - Multi-element composition with coordinate transformation
  - Resolution-independent rendering for various export sizes
- **`ImageFilterUtility`**: Custom Core Image filter implementations
  - Professional-grade color adjustments beyond standard CIFilter capabilities
  - ITU-R BT.709 luminance-based selective adjustments

#### Professional-Grade Color Adjustments
Sophisticated image processing techniques implemented in UseCases/Rendering/:

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

**Models (GLogo/Models/) - Domain Layer**:
- ✅ Allowed: Pure data structures using struct/class
- ✅ Allowed: Codable conformance, computed properties, helper methods (data transformation only)
- ✅ Allowed: Protocol definitions for domain concepts
- ❌ Prohibited: @Published, ObservableObject (these belong in ViewModels)
- ❌ Prohibited: Business logic (belongs in UseCases)
- ❌ Prohibited: References to View, ViewModel, or UseCase
- ❌ Prohibited: Framework-specific code beyond basic UIKit types (UIImage, CGPoint, etc.)

**UseCases (GLogo/UseCases/) - Application Business Rules Layer**:
- ✅ Allowed: All business logic implementation
- ✅ Allowed: Coordinator, Service, Policy, Repository patterns
- ✅ Allowed: Dependencies on Models and other UseCases
- ✅ Allowed: Protocol definitions for dependency injection
- ✅ Allowed: Framework imports when necessary (Vision, Core Image, Photos, etc.)
- ✅ Allowed: Stateless operations (preferred) or minimal state
- ❌ Prohibited: @Published, ObservableObject (these belong in ViewModels)
- ❌ Prohibited: Dependencies on ViewModels or Views
- ❌ Prohibited: Direct UI manipulation
- ❌ Prohibited: SwiftUI imports (use UIKit when UI framework needed)

**ViewModels (GLogo/ViewModels/) - Interface Adapters Layer**:
- ✅ Allowed: ObservableObject conformance, @Published properties
- ✅ Allowed: Presentation state management
- ✅ Allowed: Dependencies on UseCases (via dependency injection)
- ✅ Allowed: Transforming UseCase results into view-ready state
- ✅ Allowed: Coordinating multiple UseCases for complex user flows
- ❌ Prohibited: Business logic implementation (must delegate to UseCases)
- ❌ Prohibited: Direct Model manipulation (only through UseCases)
- ❌ Prohibited: Direct references to Views (callbacks/closures are acceptable)
- ❌ Prohibited: Direct UI component manipulation
- ❌ Prohibited: Complex algorithms or data processing (belongs in UseCases)

**Views (GLogo/Views/) - UI Layer**:
- ✅ Allowed: Declarative UI using SwiftUI
- ✅ Allowed: Observing ViewModels via @ObservedObject/@StateObject
- ✅ Allowed: Forwarding user actions to ViewModel method calls
- ✅ Allowed: Minimal local UI state (animation flags, focus state, etc.)
- ✅ Allowed: UIKit integration via UIViewRepresentable for performance
- ❌ Prohibited: Business logic implementation
- ❌ Prohibited: Direct Model manipulation
- ❌ Prohibited: Direct UseCase instantiation or method calls
- ❌ Prohibited: Complex data processing or transformation

**Utilities (GLogo/Utils/) - Shared Utilities**:
- ✅ Allowed: Pure functions (coordinate calculations, etc.)
- ✅ Allowed: Static methods, extensions
- ✅ Allowed: Helper types used across layers
- ❌ Prohibited: State retention
- ❌ Prohibited: Dependencies on View, ViewModel, or UseCase
- ❌ Prohibited: Business logic (belongs in UseCases)

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

#### Architecture Compliance (MVVM + Clean Architecture)
- [ ] Fully adheres to MVVM + Clean Architecture pattern
- [ ] Dependency rule followed: Views → ViewModels → UseCases → Models
- [ ] Models contain no business logic (pure data structures only)
- [ ] UseCases contain all business logic (no business logic in ViewModels or Views)
- [ ] ViewModels delegate to UseCases (no direct business logic implementation)
- [ ] Views contain no data processing (only presentation logic)
- [ ] No circular dependencies between layers
- [ ] Proper dependency injection used for UseCases in ViewModels
- [ ] Repository pattern used for all data access operations

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
- MVVM + Clean Architecture violations found → **Immediate refactoring required**
- Business logic in ViewModels/Views (should be in UseCases) → **Must be moved to UseCases**
- Layer dependency violations (e.g., UseCase depending on ViewModel) → **Must be refactored**
- Missing dependency injection in ViewModels → **Must be added**
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
1. **Strictly adhere to MVVM + Clean Architecture pattern** - Architecture violations require immediate refactoring
2. **Follow the Dependency Rule** - Dependencies must only point inward (Views → ViewModels → UseCases → Models)
3. **All business logic in UseCases layer** - ViewModels must delegate to UseCases
4. **Use Japanese comments** - All comments must be written in Japanese
5. **Separate sections with MARK** - Mandatory for all files

**🟡 IMPORTANT - Essential Implementation Guidelines:**
6. **Use dependency injection** for UseCases in ViewModels
7. **Profile memory usage** regularly using Instruments and Address Sanitizer
8. **Use autoreleasepool** for memory-intensive operations
9. **Implement weak references** in callback patterns
10. **Cache expensive calculations** (coordinate transformations, filter results)
11. **Validate Core Image filter availability** before use
12. **Profile performance regularly** during development
13. **Follow Swift 6.0 concurrency guidelines** strictly
14. **Keep UseCases framework-agnostic** when possible (prefer UIKit over SwiftUI in UseCases)
15. **Use Coordinator pattern** for complex multi-step workflows in UseCases