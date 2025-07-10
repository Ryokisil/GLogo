import Foundation
import CoreImage

// Test program to investigate CIUnsharpMask parameter ranges
// This demonstrates the original implementation that might have caused crashes

func testUnsharpMaskParameters() {
    print("Testing CIUnsharpMask parameter ranges...")
    
    // Create a test image
    let testImage = CIImage(color: CIColor.red).cropped(to: CGRect(x: 0, y: 0, width: 100, height: 100))
    
    guard let filter = CIFilter(name: "CIUnsharpMask") else {
        print("ERROR: CIUnsharpMask filter not available")
        return
    }
    
    // Get filter attributes to understand parameter ranges
    let attributes = filter.attributes
    print("Filter attributes: \(attributes)")
    
    // Test original parameters that caused crashes
    let testCases = [
        ("Original problematic", 3.0, 2.5, 0.0),
        ("Safe current", 2.0, 1.0, 0.0),
        ("Conservative", 1.0, 0.5, 0.0),
        ("Extreme high", 5.0, 10.0, 1.0),
        ("Negative", -1.0, -1.0, -1.0)
    ]
    
    for (name, intensity, radius, threshold) in testCases {
        print("\n--- Testing \(name): intensity=\(intensity), radius=\(radius), threshold=\(threshold) ---")
        
        filter.setValue(testImage, forKey: kCIInputImageKey)
        
        do {
            filter.setValue(intensity, forKey: "inputIntensity")
            filter.setValue(radius, forKey: "inputRadius")
            filter.setValue(threshold, forKey: "inputThreshold")
            
            if let outputImage = filter.outputImage {
                print("SUCCESS: Filter applied successfully")
                print("Output extent: \(outputImage.extent)")
            } else {
                print("ERROR: Filter returned nil output image")
            }
        } catch {
            print("ERROR: Exception caught: \(error)")
        }
    }
}

// Run the test
testUnsharpMaskParameters()