import Foundation
import SwiftUI

/**
 * KairoExample - Comprehensive example of how to use Kairo in your app
 * 
 * This file demonstrates how to integrate Kairo into your iOS app to automatically
 * throttle performance based on device health conditions. It shows real-world
 * usage patterns and best practices.
 * 
 * Key integration points:
 * - App lifecycle management
 * - Network request throttling
 * - Image quality adjustment
 * - Background task management
 * - User interface updates
 */

/**
 * ExampleApp - Main app class showing Kairo integration
 * 
 * This class demonstrates how to integrate Kairo into your app's main lifecycle.
 * It shows how to start monitoring, handle policy updates, and clean up resources.
 */
@main
struct ExampleApp: App {
    /// Kairo instance for performance monitoring
    @StateObject private var kairo = Kairo()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(kairo)
                .onAppear {
                    // Start Kairo when the app appears
                    Task {
                        await kairo.start()
                    }
                }
                .onDisappear {
                    // Stop Kairo when the app disappears
                    Task {
                        await kairo.stop()
                    }
                }
        }
    }
}

/**
 * ContentView - Main view showing Kairo integration
 * 
 * This view demonstrates how to use Kairo in a SwiftUI app. It shows
 * how to display current device health, make network requests with throttling,
 * and adjust UI based on performance policies.
 */
struct ContentView: View {
    /// Kairo instance from environment
    @EnvironmentObject var kairo: Kairo
    
    /// Current device health information
    @State private var healthInfo: HealthSnapshot?
    
    /// Current performance policy
    @State private var currentPolicy: Policy?
    
    /// Network request status
    @State private var requestStatus: String = "Ready"
    
    /// Image quality recommendation
    @State private var imageQuality: String = "Original"
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                Text("Kairo Performance Monitor")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Health Status Card
                if let health = healthInfo {
                    HealthStatusCard(health: health)
                }
                
                // Policy Status Card
                if let policy = currentPolicy {
                    PolicyStatusCard(policy: policy)
                }
                
                // Network Request Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Network Requests")
                        .font(.headline)
                    
                    Button("Make Test Request") {
                        Task {
                            await makeTestRequest()
                        }
                    }
                    .disabled(requestStatus == "Requesting...")
                    
                    Text("Status: \(requestStatus)")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                // Image Quality Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Image Quality")
                        .font(.headline)
                    
                    Text("Recommended: \(imageQuality)")
                        .foregroundColor(.secondary)
                    
                    Button("Load Sample Image") {
                        Task {
                            await loadSampleImage()
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                Spacer()
            }
            .padding()
            .onAppear {
                // Start monitoring health updates
                Task {
                    await startHealthMonitoring()
                }
            }
        }
    }
    
    /**
     * Start monitoring health updates from Kairo
     * 
     * This method demonstrates how to subscribe to health updates and
     * react to changes in device conditions.
     */
    private func startHealthMonitoring() async {
        // Get initial health information
        healthInfo = await kairo.getCurrentHealth()
        currentPolicy = kairo.currentPolicy
        
        // Subscribe to health updates
        let healthStream = await kairo.healthStream()
        for await health in healthStream {
            await MainActor.run {
                self.healthInfo = health
                self.currentPolicy = kairo.currentPolicy
                self.imageQuality = kairo.currentPolicy.imageVariant.description
            }
        }
    }
    
    /**
     * Make a test network request with Kairo throttling
     * 
     * This method demonstrates how to make network requests that are
     * automatically throttled based on device health conditions.
     */
    private func makeTestRequest() async {
        requestStatus = "Requesting..."
        
        do {
            // Check if the request should be allowed
            let shouldAllow = await kairo.shouldAllowOperation(.networkRequest(priority: .normal))
            
            if !shouldAllow {
                requestStatus = "Request blocked by Kairo"
                return
            }
            
            // Simulate a network request
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            requestStatus = "Request completed successfully"
            
        } catch {
            requestStatus = "Request failed: \(error.localizedDescription)"
        }
    }
    
    /**
     * Load a sample image with quality adjustment
     * 
     * This method demonstrates how to adjust image quality based on
     * current device health conditions.
     */
    private func loadSampleImage() async {
        // Get recommended image quality
        let recommendedQuality = await kairo.getRecommendedImageQuality()
        
        // Adjust image loading based on quality recommendation
        switch recommendedQuality {
        case .original:
            // Load full quality image
            print("Loading original quality image")
        case .large:
            // Load high quality image
            print("Loading large quality image")
        case .medium:
            // Load medium quality image
            print("Loading medium quality image")
        case .small:
            // Load low quality image
            print("Loading small quality image")
        }
    }
}

/**
 * HealthStatusCard - View showing current device health
 * 
 * This view displays the current device health information in a
 * user-friendly format. It shows battery level, thermal state,
 * and network conditions.
 */
struct HealthStatusCard: View {
    let health: HealthSnapshot
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Device Health")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Battery: \(Int(health.batteryLevel * 100))%")
                    Text("Thermal: \(thermalStateDescription(health.thermalState))")
                    Text("Network: \(networkStatusDescription(health.networkReachability))")
                }
                
                Spacer()
                
                // Health indicator
                Circle()
                    .fill(healthColor)
                    .frame(width: 20, height: 20)
            }
            
            Text("Overall Health: \(Int(health.overallHealthScore * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    /// Color indicator for health status
    private var healthColor: Color {
        if health.overallHealthScore > 0.8 {
            return .green
        } else if health.overallHealthScore > 0.5 {
            return .yellow
        } else {
            return .red
        }
    }
    
    /// Human-readable thermal state description
    private func thermalStateDescription(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "Normal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
    
    /// Human-readable network status description
    private func networkStatusDescription(_ status: NWPath.Status) -> String {
        switch status {
        case .satisfied: return "Connected"
        case .requiresConnection: return "No Connection"
        case .satisfiable: return "Limited"
        @unknown default: return "Unknown"
        }
    }
}

/**
 * PolicyStatusCard - View showing current performance policy
 * 
 * This view displays the current performance policy information,
 * including network limits, image quality, and ML permissions.
 */
struct PolicyStatusCard: View {
    let policy: Policy
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Performance Policy")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Network Limit: \(policy.maxNetworkConcurrent)")
                    Text("Image Quality: \(policy.imageVariant.description)")
                    Text("Background ML: \(policy.allowBackgroundMl ? "Allowed" : "Blocked")")
                }
                
                Spacer()
                
                // Policy level indicator
                Text(policy.healthLevel.description)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(policyColor)
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    /// Color indicator for policy level
    private var policyColor: Color {
        switch policy.healthLevel {
        case .high: return .green
        case .medium: return .yellow
        case .low: return .orange
        case .critical: return .red
        }
    }
}

/**
 * NetworkManager - Example network manager using Kairo
 * 
 * This class demonstrates how to create a network manager that
 * automatically applies Kairo's performance throttling.
 */
class NetworkManager: ObservableObject {
    /// Kairo instance for performance monitoring
    private let kairo: Kairo
    
    /// Network client for making requests
    private let netClient: NetClient
    
    /// Logger for debugging
    private let logger = Logger(category: "NetworkManager")
    
    /**
     * Initialize the network manager with Kairo
     * 
     * - Parameter kairo: Kairo instance for performance monitoring
     */
    init(kairo: Kairo) {
        self.kairo = kairo
        self.netClient = NetClient(logger: logger)
        
        // Start monitoring policy updates
        Task {
            await startPolicyMonitoring()
        }
    }
    
    /**
     * Start monitoring policy updates from Kairo
     * 
     * This method demonstrates how to subscribe to policy updates
     * and apply them to your network client.
     */
    private func startPolicyMonitoring() async {
        // Subscribe to policy updates
        let policyStream = await kairo.healthStream()
        for await _ in policyStream {
            // Update network client policy
            await netClient.updatePolicy(kairo.currentPolicy)
        }
    }
    
    /**
     * Make a network request with automatic throttling
     * 
     * - Parameter url: The URL to request
     * - Parameter priority: Priority level for the request
     * - Returns: The network response
     * - Throws: NetworkError if the request fails
     * 
     * This method demonstrates how to make network requests that are
     * automatically throttled based on device health conditions.
     */
    func request(url: URL, priority: NetworkRequest.RequestPriority = .normal) async throws -> NetworkResponse {
        // Check if the request should be allowed
        let shouldAllow = await kairo.shouldAllowOperation(.networkRequest(priority: priority))
        
        guard shouldAllow else {
            logger.warning("Request blocked by Kairo: \(url)")
            throw KairoError.cancelled
        }
        
        // Create network request
        let request = NetworkRequest(
            url: url,
            method: .GET,
            priority: priority
        )
        
        // Make the request through the network client
        return try await netClient.request(request)
    }
}

/**
 * ImageManager - Example image manager using Kairo
 * 
 * This class demonstrates how to create an image manager that
 * automatically adjusts image quality based on device health.
 */
class ImageManager: ObservableObject {
    /// Kairo instance for performance monitoring
    private let kairo: Kairo
    
    /// Logger for debugging
    private let logger = Logger(category: "ImageManager")
    
    /**
     * Initialize the image manager with Kairo
     * 
     * - Parameter kairo: Kairo instance for performance monitoring
     */
    init(kairo: Kairo) {
        self.kairo = kairo
    }
    
    /**
     * Load an image with automatic quality adjustment
     * 
     * - Parameter url: The URL of the image to load
     * - Returns: The loaded image
     * - Throws: ImageError if the image fails to load
     * 
     * This method demonstrates how to load images with automatic
     * quality adjustment based on device health conditions.
     */
    func loadImage(url: URL) async throws -> UIImage {
        // Get recommended image quality
        let recommendedQuality = await kairo.getRecommendedImageQuality()
        
        // Adjust image URL based on quality recommendation
        let adjustedURL = adjustImageURL(url, for: recommendedQuality)
        
        logger.info("Loading image with quality: \(recommendedQuality.description)")
        
        // Load the image
        let (data, _) = try await URLSession.shared.data(from: adjustedURL)
        
        guard let image = UIImage(data: data) else {
            throw ImageError.invalidData
        }
        
        return image
    }
    
    /**
     * Adjust image URL based on quality recommendation
     * 
     * - Parameters:
     *   - url: Original image URL
     *   - quality: Recommended quality level
     * - Returns: Adjusted URL for the recommended quality
     * 
     * This method demonstrates how to adjust image URLs based on
     * quality recommendations from Kairo.
     */
    private func adjustImageURL(_ url: URL, for quality: Policy.ImageVariant) -> URL {
        // In a real app, you would adjust the URL based on your image service
        // For example, adding quality parameters or using different endpoints
        
        switch quality {
        case .original:
            return url
        case .large:
            return url.appendingPathComponent("large")
        case .medium:
            return url.appendingPathComponent("medium")
        case .small:
            return url.appendingPathComponent("small")
        }
    }
}

/**
 * BackgroundTaskManager - Example background task manager using Kairo
 * 
 * This class demonstrates how to create a background task manager that
 * respects Kairo's performance policies.
 */
class BackgroundTaskManager: ObservableObject {
    /// Kairo instance for performance monitoring
    private let kairo: Kairo
    
    /// Logger for debugging
    private let logger = Logger(category: "BackgroundTaskManager")
    
    /**
     * Initialize the background task manager with Kairo
     * 
     * - Parameter kairo: Kairo instance for performance monitoring
     */
    init(kairo: Kairo) {
        self.kairo = kairo
    }
    
    /**
     * Perform a background task with automatic throttling
     * 
     * - Parameter task: The background task to perform
     * - Returns: The result of the task
     * - Throws: TaskError if the task fails
     * 
     * This method demonstrates how to perform background tasks that
     * are automatically throttled based on device health conditions.
     */
    func performBackgroundTask<T>(_ task: @escaping () async throws -> T) async throws -> T {
        // Check if background tasks should be allowed
        let shouldAllow = await kairo.shouldAllowOperation(.backgroundTask)
        
        guard shouldAllow else {
            logger.warning("Background task blocked by Kairo")
            throw TaskError.blockedByPolicy
        }
        
        // Check if ML operations are allowed
        let allowML = await kairo.shouldAllowBackgroundML()
        
        if !allowML && isMLTask(task) {
            logger.warning("ML task blocked by Kairo policy")
            throw TaskError.blockedByPolicy
        }
        
        // Perform the task
        return try await task()
    }
    
    /**
     * Check if a task is an ML task
     * 
     * - Parameter task: The task to check
     * - Returns: True if the task is an ML task
     * 
     * This method demonstrates how to identify ML tasks that should
     * be blocked during poor device conditions.
     */
    private func isMLTask<T>(_ task: @escaping () async throws -> T) -> Bool {
        // In a real app, you would implement logic to identify ML tasks
        // For example, checking task names, types, or other identifiers
        return false
    }
}

/**
 * Error types for the example
 */
enum ImageError: Error {
    case invalidData
    case loadFailed
}

enum TaskError: Error {
    case blockedByPolicy
    case executionFailed
}

/**
 * Usage Examples - Additional usage patterns
 * 
 * This section demonstrates additional usage patterns and best practices
 * for integrating Kairo into your app.
 */

/**
 * Example 1: Basic Integration
 * 
 * This example shows the most basic integration of Kairo into your app.
 * It demonstrates starting monitoring and checking device health.
 */
func basicIntegrationExample() async {
    // Create Kairo instance
    let kairo = Kairo()
    
    // Start monitoring
    await kairo.start()
    
    // Check current health
    let health = await kairo.getCurrentHealth()
    print("Battery level: \(health.batteryLevel)")
    print("Thermal state: \(health.thermalState)")
    
    // Check if an operation should be allowed
    let shouldAllow = await kairo.shouldAllowOperation(.networkRequest(priority: .normal))
    print("Network requests allowed: \(shouldAllow)")
    
    // Stop monitoring when done
    await kairo.stop()
}

/**
 * Example 2: Network Request Throttling
 * 
 * This example shows how to make network requests that are automatically
 * throttled based on device health conditions.
 */
func networkRequestExample() async {
    let kairo = Kairo()
    await kairo.start()
    
    // Create network request
    let request = NetworkRequest(
        url: URL(string: "https://api.example.com/data")!,
        method: .GET,
        priority: .high
    )
    
    // Check if request should be allowed
    let shouldAllow = await kairo.shouldAllowOperation(.networkRequest(priority: .high))
    
    if shouldAllow {
        // Make the request
        print("Making network request...")
        // ... perform actual request
    } else {
        print("Request blocked due to poor device conditions")
    }
    
    await kairo.stop()
}

/**
 * Example 3: Image Quality Adjustment
 * 
 * This example shows how to adjust image quality based on device health.
 */
func imageQualityExample() async {
    let kairo = Kairo()
    await kairo.start()
    
    // Get recommended image quality
    let recommendedQuality = await kairo.getRecommendedImageQuality()
    
    // Adjust image loading based on quality
    switch recommendedQuality {
    case .original:
        print("Loading original quality images")
    case .large:
        print("Loading high quality images")
    case .medium:
        print("Loading medium quality images")
    case .small:
        print("Loading low quality images")
    }
    
    await kairo.stop()
}

/**
 * Example 4: Background Task Management
 * 
 * This example shows how to manage background tasks with Kairo.
 */
func backgroundTaskExample() async {
    let kairo = Kairo()
    await kairo.start()
    
    // Check if background tasks should be allowed
    let shouldAllow = await kairo.shouldAllowOperation(.backgroundTask)
    
    if shouldAllow {
        // Perform background task
        print("Performing background task...")
        // ... perform actual task
    } else {
        print("Background task blocked due to poor device conditions")
    }
    
    await kairo.stop()
}

/**
 * Example 5: Custom Configuration
 * 
 * This example shows how to customize Kairo's configuration for your app's needs.
 */
func customConfigurationExample() async {
    // Create custom configuration
    let config = KairoConfig(
        networkMaxConcurrent: 4,        // Limit to 4 concurrent requests
        lowBatteryThreshold: 0.20,      // Warn at 20% battery
        debounceMillis: 500             // 500ms debounce
    )
    
    // Create Kairo with custom configuration
    let kairo = Kairo(config: config)
    await kairo.start()
    
    // Use Kairo with custom settings
    let health = await kairo.getCurrentHealth()
    print("Custom configuration active")
    
    await kairo.stop()
}
