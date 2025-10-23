import Foundation
import Network

/**
 * Kairo - Intelligent Performance Throttling Framework
 * 
 * Kairo is a Swift framework that automatically adjusts app performance based on
 * device health conditions like battery temperature, network quality, and thermal state.
 * It helps maintain usability during degraded conditions by intelligently throttling
 * resource-intensive operations.
 * 
 * Key Features:
 * - Battery temperature and level monitoring
 * - Network quality assessment
 * - Thermal state tracking
 * - Automatic performance throttling
 * - Circuit breaker pattern for network requests
 * - Background task management
 */

/**
 * The main Kairo class that orchestrates performance monitoring and throttling.
 * 
 * This is the primary interface for your app to interact with Kairo.
 * It manages all the monitoring components and provides a simple API
 * for your app to check current performance policies.
 */
public class Kairo: ObservableObject {
    
    // MARK: - Properties
    
    /**
     * Configuration object that holds all the settings for Kairo.
     * This includes thresholds for battery levels, network limits, etc.
     * 
     * @Published means this property will automatically notify SwiftUI views
     * when it changes, allowing the UI to react to performance changes.
     */
    @Published public private(set) var currentPolicy: Policy
    
    /**
     * The health monitor that tracks device conditions.
     * This is an 'actor' which means it's thread-safe and can be accessed
     * from multiple threads without data races.
     */
    private let healthMonitor: HealthMonitor
    
    /**
     * The policy engine that decides what performance level to use
     * based on current health conditions.
     */
    private let policyEngine: PolicyEngine
    
    /**
     * The job scheduler that manages background tasks and ensures
     * they don't overwhelm the system during poor conditions.
     */
    private let jobScheduler: JobScheduler
    
    /**
     * Configuration object that holds all the settings for Kairo.
     */
    private let config: KairoConfig
    
    /**
     * Logger for debugging and monitoring Kairo's behavior.
     */
    private let logger: Logger
    
    // MARK: - Initialization
    
    /**
     * Initialize Kairo with a custom configuration.
     * 
     * - Parameter config: Configuration object with settings like battery thresholds
     * - Returns: A new Kairo instance ready to start monitoring
     * 
     * This is the main way to create a Kairo instance. You can customize
     * the behavior by providing your own KairoConfig.
     */
    public init(config: KairoConfig = .default) {
        self.config = config
        
        // Initialize the logger first - we'll need it for other components
        self.logger = Logger(category: "Kairo")
        
        // Initialize the health monitor that will track device conditions
        self.healthMonitor = HealthMonitor()
        
        // Initialize the policy engine that decides performance levels
        self.policyEngine = PolicyEngine(config: config, logger: logger)
        
        // Initialize the job scheduler for managing background tasks
        self.jobScheduler = JobScheduler(config: config, logger: logger)
        
        // Start with a default high-performance policy
        // This will be updated as we monitor device conditions
        self.currentPolicy = Policy(
            maxNetworkConcurrent: config.networkMaxConcurrent,
            allowBackgroundMl: true,
            imageVariant: .original,
            preferCacheWhenUnhealthy: false
        )
        
        logger.info("Kairo initialized with config: \(config)")
    }
    
    // MARK: - Public API
    
    /**
     * Start monitoring device health and begin automatic performance adjustments.
     * 
     * This method should be called when your app starts up. It begins
     * monitoring battery, thermal state, and network conditions, then
     * automatically adjusts performance policies based on what it finds.
     * 
     * This is an async function, so you need to call it with 'await' or
     * from within an async context.
     */
    public func start() async {
        logger.info("Starting Kairo performance monitoring...")
        
        do {
            // Start the health monitor to begin tracking device conditions
            await healthMonitor.start()
            
            // Start monitoring health changes and updating policies
            await startPolicyMonitoring()
            
            logger.info("Kairo started successfully")
        } catch {
            logger.error("Failed to start Kairo: \(error)")
        }
    }
    
    /**
     * Stop monitoring and clean up resources.
     * 
     * Call this when your app is shutting down or when you no longer
     * need performance monitoring.
     */
    public func stop() async {
        logger.info("Stopping Kairo...")
        
        // Stop the health monitor
        await healthMonitor.stop()
        
        // Stop the job scheduler
        await jobScheduler.stop()
        
        logger.info("Kairo stopped")
    }
    
    /**
     * Get the current health snapshot of the device.
     * 
     * - Returns: A HealthSnapshot containing current battery, thermal, and network info
     * 
     * This is useful if you want to display current device conditions to the user
     * or make custom decisions based on health data.
     */
    public func getCurrentHealth() async -> HealthSnapshot {
        return await healthMonitor.getCurrentSnapshot()
    }
    
    /**
     * Check if a specific operation should be allowed based on current conditions.
     * 
     * - Parameter operation: The type of operation you want to perform
     * - Returns: True if the operation should be allowed, false if it should be throttled
     * 
     * Use this method before performing expensive operations like:
     * - Large image downloads
     * - Machine learning inference
     * - Heavy network requests
     * - Background processing
     */
    public func shouldAllowOperation(_ operation: OperationType) async -> Bool {
        let health = await getCurrentHealth()
        return policyEngine.shouldAllowOperation(operation, given: health, currentPolicy: currentPolicy)
    }
    
    /**
     * Get the recommended image quality for the current conditions.
     * 
     * - Returns: The recommended ImageVariant (original, small, medium, large)
     * 
     * Use this to automatically adjust image quality based on device health.
     * During poor conditions, Kairo will recommend smaller images to save bandwidth and processing.
     */
    public func getRecommendedImageQuality() async -> Policy.ImageVariant {
        return currentPolicy.imageVariant
    }
    
    /**
     * Get the maximum number of concurrent network requests allowed.
     * 
     * - Returns: The maximum number of simultaneous network requests
     * 
     * Use this to limit your network request concurrency based on current conditions.
     * During poor network conditions, this number will be lower.
     */
    public func getMaxConcurrentRequests() async -> Int {
        return currentPolicy.maxNetworkConcurrent
    }
    
    /**
     * Check if background machine learning should be allowed.
     * 
     * - Returns: True if ML operations can run in the background
     * 
     * ML operations are CPU-intensive and can heat up the device.
     * During thermal stress, this will return false.
     */
    public func shouldAllowBackgroundML() async -> Bool {
        return currentPolicy.allowBackgroundMl
    }
    
    // MARK: - Private Methods
    
    /**
     * Start monitoring health changes and updating policies accordingly.
     * 
     * This is a private method that runs in the background and continuously
     * monitors device health, updating the performance policy as conditions change.
     */
    private func startPolicyMonitoring() async {
        // Create an async stream that will emit health snapshots whenever conditions change
        let healthStream = await healthMonitor.healthStream()
        
        // Process each health update as it comes in
        for await healthSnapshot in healthStream {
            // Update the policy based on the new health information
            let newPolicy = await policyEngine.evaluatePolicy(for: healthSnapshot)
            
            // Update our current policy (this will trigger UI updates if using SwiftUI)
            await MainActor.run {
                self.currentPolicy = newPolicy
            }
            
            logger.debug("Policy updated based on health: \(healthSnapshot)")
        }
    }
}

/**
 * Types of operations that can be checked for throttling.
 * 
 * This enum helps categorize different types of operations so Kairo
 * can make intelligent decisions about what to throttle.
 */
public enum OperationType: Sendable {
    case networkRequest(priority: NetworkPriority)
    case imageProcessing(size: ImageSize)
    case machineLearningInference
    case backgroundTask
    case fileDownload(size: Int64)
    case videoProcessing
    
    /**
     * Priority levels for network requests.
     * Higher priority requests are less likely to be throttled.
     */
    public enum NetworkPriority: Int, Sendable {
        case low = 1
        case normal = 2
        case high = 3
        case critical = 4
    }
    
    /**
     * Image size categories for processing decisions.
     */
    public enum ImageSize: Sendable {
        case small      // < 1MB
        case medium     // 1-10MB
        case large      // > 10MB
    }
}
