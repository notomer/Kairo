# Kairo - Intelligent Performance Throttling Framework

Kairo is a Swift framework that automatically adjusts app performance based on device health conditions like battery temperature, network quality, and thermal state. It helps maintain usability during degraded conditions by intelligently throttling resource-intensive operations.

## 🚀 Key Features

- **Battery & Thermal Monitoring**: Real-time monitoring of battery level, temperature, and thermal state
- **Network Quality Assessment**: Automatic detection of network conditions and constraints
- **Intelligent Throttling**: Smart performance adjustments based on device health
- **Circuit Breaker Pattern**: Fault tolerance for network operations
- **Async/Await Support**: Modern Swift concurrency with full async/await support
- **SwiftUI Integration**: Built-in support for SwiftUI with `@Published` properties
- **Comprehensive Logging**: Detailed logging for debugging and monitoring

## 📱 Why Use Kairo?

Modern mobile devices face various challenges that can impact app performance:

- **Battery Temperature**: High temperatures can cause thermal throttling
- **Low Battery**: Limited power affects processing capabilities
- **Poor Network**: Slow or expensive connections impact user experience
- **Thermal Stress**: Intensive operations can overheat the device
- **Resource Constraints**: Limited memory and processing power

Kairo automatically detects these conditions and adjusts your app's behavior to maintain usability while protecting device health.

## 🛠 Installation

### Swift Package Manager

Add Kairo to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/your-username/Kairo.git", from: "1.0.0")
]
```

### Manual Installation

1. Clone the repository
2. Add the `Sources/Kairo` folder to your Xcode project
3. Import Kairo in your Swift files

## 🚀 Quick Start

### Basic Integration

```swift
import Kairo

class AppDelegate: NSObject, UIApplicationDelegate {
    private let kairo = Kairo()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Start Kairo monitoring
        Task {
            await kairo.start()
        }
        return true
    }
}
```

### SwiftUI Integration

```swift
import SwiftUI
import Kairo

struct ContentView: View {
    @StateObject private var kairo = Kairo()
    
    var body: some View {
        VStack {
            Text("App Content")
        }
        .onAppear {
            Task {
                await kairo.start()
            }
        }
        .onDisappear {
            Task {
                await kairo.stop()
            }
        }
    }
}
```

## 📖 Usage Examples

### 1. Network Request Throttling

```swift
// Check if network request should be allowed
let shouldAllow = await kairo.shouldAllowOperation(.networkRequest(priority: .high))

if shouldAllow {
    // Make your network request
    let response = try await URLSession.shared.data(from: url)
} else {
    // Handle blocked request (e.g., show cached data)
    print("Request blocked due to poor device conditions")
}
```

### 2. Image Quality Adjustment

```swift
// Get recommended image quality
let recommendedQuality = await kairo.getRecommendedImageQuality()

// Adjust image loading based on quality
switch recommendedQuality {
case .original:
    // Load full quality images
case .large:
    // Load high quality images
case .medium:
    // Load medium quality images
case .small:
    // Load low quality images
}
```

### 3. Background Task Management

```swift
// Check if background tasks should be allowed
let shouldAllow = await kairo.shouldAllowOperation(.backgroundTask)

if shouldAllow {
    // Perform background task
    await performBackgroundWork()
} else {
    // Skip or defer background task
    print("Background task blocked due to poor device conditions")
}
```

### 4. Machine Learning Operations

```swift
// Check if ML operations should be allowed
let allowML = await kairo.shouldAllowBackgroundML()

if allowML {
    // Run ML inference
    await runMLInference()
} else {
    // Skip ML operations to preserve battery and thermal state
    print("ML operations blocked due to poor device conditions")
}
```

## 🔧 Configuration

### Custom Configuration

```swift
let config = KairoConfig(
    networkMaxConcurrent: 4,        // Limit to 4 concurrent requests
    lowBatteryThreshold: 0.20,      // Warn at 20% battery
    debounceMillis: 500             // 500ms debounce
)

let kairo = Kairo(config: config)
```

### Policy Customization

```swift
// Get current policy
let policy = kairo.currentPolicy

// Check specific policy settings
print("Max concurrent requests: \(policy.maxNetworkConcurrent)")
print("Image quality: \(policy.imageVariant)")
print("Background ML allowed: \(policy.allowBackgroundMl)")
```

## 📊 Health Monitoring

### Device Health Information

```swift
// Get current device health
let health = await kairo.getCurrentHealth()

print("Battery level: \(health.batteryLevel)")
print("Thermal state: \(health.thermalState)")
print("Network status: \(health.networkReachability)")
print("Overall health score: \(health.overallHealthScore)")
```

### Health Stream Monitoring

```swift
// Subscribe to health updates
let healthStream = await kairo.healthStream()
for await health in healthStream {
    // React to health changes
    print("Health updated: \(health.overallHealthScore)")
}
```

## 🌐 Network Management

### Network Client

```swift
import Kairo

class NetworkManager {
    private let kairo: Kairo
    private let netClient: NetClient
    
    init(kairo: Kairo) {
        self.kairo = kairo
        self.netClient = NetClient(logger: Logger(category: "NetworkManager"))
    }
    
    func makeRequest(url: URL) async throws -> NetworkResponse {
        // Check if request should be allowed
        let shouldAllow = await kairo.shouldAllowOperation(.networkRequest(priority: .normal))
        
        guard shouldAllow else {
            throw KairoError.cancelled
        }
        
        // Make the request
        let request = NetworkRequest(url: url, method: .GET)
        return try await netClient.request(request)
    }
}
```

### Circuit Breaker Pattern

```swift
// Create circuit breaker for fault tolerance
let circuitBreaker = CircuitBreaker(name: "API", logger: logger)

// Execute operation through circuit breaker
let result = try await circuitBreaker.execute {
    try await apiCall()
}
```

## 🔍 Advanced Features

### Custom Operation Types

```swift
// Define custom operation types
enum CustomOperationType: OperationType {
    case imageProcessing(size: ImageSize)
    case videoProcessing
    case dataSync
    
    enum ImageSize {
        case small, medium, large
    }
}

// Check custom operations
let shouldAllow = await kairo.shouldAllowOperation(.imageProcessing(size: .large))
```

### Performance Metrics

```swift
// Get network performance metrics
let metrics = netClient.getMetrics()
print("Success rate: \(metrics.getSuccessRate())")
print("Average response time: \(metrics.getAverageResponseTime())")
```

### Disk Space Monitoring

```swift
import Kairo

let diskSpace = DiskSpace(logger: logger)

// Start monitoring disk space
await diskSpace.startMonitoring()

// Check if space is low
if diskSpace.isLow() {
    print("Disk space is low")
}

// Get space recommendations
let recommendations = await diskSpace.getSpaceRecommendations()
```

### Network Reachability

```swift
import Kairo

let reachability = Reachability(logger: logger)

// Start monitoring network connectivity
await reachability.startMonitoring()

// Check connection status
if reachability.isConnected() {
    print("Device is connected to network")
}

// Subscribe to network changes
let statusStream = await reachability.statusStream()
for await status in statusStream {
    print("Network status: \(status.statusDescription)")
}
```

## 🧪 Testing

### Unit Tests

```swift
import XCTest
@testable import Kairo

class KairoTests: XCTestCase {
    func testHealthMonitoring() async throws {
        let kairo = Kairo()
        await kairo.start()
        
        let health = await kairo.getCurrentHealth()
        XCTAssertGreaterThanOrEqual(health.batteryLevel, 0.0)
        XCTAssertLessThanOrEqual(health.batteryLevel, 1.0)
        
        await kairo.stop()
    }
}
```

### Integration Tests

```swift
func testNetworkThrottling() async throws {
    let kairo = Kairo()
    await kairo.start()
    
    // Simulate poor conditions
    // ... set up test conditions
    
    let shouldAllow = await kairo.shouldAllowOperation(.networkRequest(priority: .normal))
    XCTAssertFalse(shouldAllow)
    
    await kairo.stop()
}
```

## 📱 Best Practices

### 1. App Lifecycle Management

```swift
class AppDelegate: NSObject, UIApplicationDelegate {
    private let kairo = Kairo()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Task {
            await kairo.start()
        }
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        Task {
            await kairo.stop()
        }
    }
}
```

### 2. SwiftUI Integration

```swift
struct ContentView: View {
    @StateObject private var kairo = Kairo()
    @State private var healthInfo: HealthSnapshot?
    
    var body: some View {
        VStack {
            if let health = healthInfo {
                HealthStatusView(health: health)
            }
            // ... rest of your UI
        }
        .onAppear {
            Task {
                await kairo.start()
                await startHealthMonitoring()
            }
        }
    }
    
    private func startHealthMonitoring() async {
        let healthStream = await kairo.healthStream()
        for await health in healthStream {
            await MainActor.run {
                self.healthInfo = health
            }
        }
    }
}
```

### 3. Network Request Patterns

```swift
func makeNetworkRequest(url: URL) async throws -> Data {
    // Check if request should be allowed
    let shouldAllow = await kairo.shouldAllowOperation(.networkRequest(priority: .normal))
    
    guard shouldAllow else {
        // Return cached data or show offline message
        throw NetworkError.blockedByPolicy
    }
    
    // Make the request
    let (data, response) = try await URLSession.shared.data(from: url)
    return data
}
```

### 4. Image Loading Patterns

```swift
func loadImage(url: URL) async throws -> UIImage {
    // Get recommended quality
    let quality = await kairo.getRecommendedImageQuality()
    
    // Adjust URL based on quality
    let adjustedURL = adjustImageURL(url, for: quality)
    
    // Load the image
    let (data, _) = try await URLSession.shared.data(from: adjustedURL)
    return UIImage(data: data)!
}
```

## 🔧 Troubleshooting

### Common Issues

1. **Kairo not starting**: Ensure you're calling `await kairo.start()` in an async context
2. **Health updates not received**: Check that you're subscribing to the health stream correctly
3. **Network requests blocked**: Verify that your operation type is supported and conditions allow it
4. **Performance issues**: Check that you're not calling Kairo methods too frequently

### Debug Logging

```swift
// Enable debug logging
let logger = Logger(category: "Kairo")
logger.debug("Kairo initialized")

// Check current status
let health = await kairo.getCurrentHealth()
print("Current health: \(health)")
```

## 📚 API Reference

### Core Classes

- **Kairo**: Main class for performance monitoring and throttling
- **HealthMonitor**: Monitors device health conditions
- **PolicyEngine**: Determines performance policies based on health
- **NetClient**: Network client with automatic throttling
- **CircuitBreaker**: Fault tolerance for network operations
- **AsyncSemaphore**: Concurrency control for operations

### Key Types

- **HealthSnapshot**: Current device health information
- **Policy**: Performance policy configuration
- **NetworkRequest**: Network request configuration
- **NetworkResponse**: Network response information
- **OperationType**: Types of operations that can be throttled

## 🤝 Contributing

We welcome contributions to Kairo! Please see our [Contributing Guide](CONTRIBUTING.md) for details on how to contribute.

### Development Setup

1. Clone the repository
2. Open `Kairo.xcodeproj` in Xcode
3. Run the tests to ensure everything works
4. Make your changes
5. Add tests for new functionality
6. Submit a pull request

## 📄 License

Kairo is released under the MIT License. See [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

- Inspired by the need for intelligent performance management in mobile apps
- Built with modern Swift concurrency patterns
- Designed for ease of use and integration

## 📞 Support

- **Documentation**: [Full API Documentation](https://kairo-docs.com)
- **Issues**: [GitHub Issues](https://github.com/your-username/Kairo/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-username/Kairo/discussions)
- **Email**: support@kairo.com

---

**Kairo** - Intelligent Performance Throttling for iOS Apps 🚀
