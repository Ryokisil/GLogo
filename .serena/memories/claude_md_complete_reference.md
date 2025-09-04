# CLAUDE.md Complete Reference - GLogo Project

## Project Overview
- **Advanced iOS image editing application** built with Swift 6.0 and SwiftUI
- **Professional-grade capabilities**: Custom Core Image filters, event-sourcing undo/redo, SwiftUI + UIKit hybrid
- **Key Features**: ITU-R BT.709 luminance masking, 20+ event types, memory-safe design, macOS Catalyst support

## Critical Architecture Patterns

### MVVM + Event Sourcing
- **EditorViewModel**: Central coordinator (1,336+ lines)
- **Event System**: 20+ specific event types with bidirectional operations
- **Memory Management**: Weak references, automatic cleanup, comprehensive leak testing

### SwiftUI + UIKit Integration
- **CanvasView**: High-performance UIKit drawing (784 lines)
- **Coordinator Pattern**: Type-safe callbacks for UIKit → SwiftUI communication
- **Coordinate System**: Dual support (display vs canvas coordinates)

## Development Commands & Standards

### Build & Test
```bash
# Standard build
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo build

# Memory leak tests (critical)
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo -only-testing:GLogoTests/ViewModelMemoryLeakTests test
```

### Code Standards
- **Primary Language**: Japanese for all comments and documentation
- **Concurrency**: Swift Concurrency preferred (`async/await`, `@MainActor`)
- **Memory**: Always use `[weak self]` in callbacks, autoreleasepool for image processing
- **Organization**: Mandatory MARK sections, protocol-oriented design

## Advanced Technical Implementation

### Custom Image Processing
- **Highlight/Shadow**: ITU-R BT.709 coefficients (R: 0.2126, G: 0.7152, B: 0.0722)
- **iOS Orientation**: Custom `createOrientedCGImage` for coordinate system fixes
- **Multi-pass Filtering**: Luminance extraction → Gamma masking → Selective adjustment → Masked blending

### Performance Optimizations
- **Selective Redrawing**: Strategic `setNeedsDisplay()` calls
- **Memory Efficiency**: Result caching, autoreleasepool usage, early returns
- **Event System**: Minimal object references, lazy evaluation, automatic history cleanup

## Testing & Quality Assurance

### Memory Leak Prevention
```swift
extension XCTestCase {
    func assertNoMemoryLeak<T: AnyObject>(_ instance: () -> T) {
        weak var weakInstance: T?
        autoreleasepool {
            let strongInstance = instance()
            weakInstance = strongInstance
        }
        XCTAssertNil(weakInstance, "Memory leak detected")
    }
}
```

### Critical Test Areas
- **ViewModelMemoryLeakTests**: ViewModel lifecycle, cross-references
- **OperationMemoryLeakTests**: Element transformations, undo/redo integrity
- **Performance Monitoring**: Large images, complex histories, real-time rendering

## Troubleshooting & Best Practices

### Common Issues
- **Swift 6.0 Concurrency**: Use `@MainActor` for UI classes
- **Core Image Failures**: Always validate filter availability
- **Memory Spikes**: Use autoreleasepool for batch operations
- **Retain Cycles**: Implement weak references in closures

### Performance Checklist
- [ ] Memory leak tests after new features
- [ ] Autoreleasepool for intensive operations
- [ ] Weak reference patterns in callbacks
- [ ] Cache expensive calculations
- [ ] Profile performance regularly

## Key Implementation Notes
- **File Structure**: Models → ViewModels → Views → Utils hierarchy
- **Error Handling**: Consistent nil returns with debug logging
- **Documentation**: `///` for API docs, `//` for implementation notes
- **Naming**: camelCase properties, PascalCase types, descriptive methods