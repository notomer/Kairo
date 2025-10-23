import Foundation

/**
 * PolicyEngine - Intelligent performance policy decision maker
 * 
 * The PolicyEngine is the "brain" of Kairo. It takes health information from the
 * HealthMonitor and decides what performance policies to apply. It uses a sophisticated
 * scoring system to balance user experience with device health.
 * 
 * Key responsibilities:
 * - Analyze device health conditions
 * - Determine appropriate performance levels
 * - Balance user experience with device protection
 * - Provide operation-specific decisions
 */

/**
 * HealthLevel - Overall device health classification
 * 
 * This enum provides a simple way to understand device health at a glance.
 * Each level corresponds to different performance policies.
 */
public enum HealthLevel: Int, Sendable, CaseIterable {
    case high = 4      // Excellent conditions - full performance
    case medium = 3    // Good conditions - slight throttling
    case low = 2       // Poor conditions - moderate throttling  
    case critical = 1  // Critical conditions - aggressive throttling
    
    /**
     * Get a human-readable description of this health level.
     */
    public var description: String {
        switch self {
        case .high:
            return "Excellent - Full performance available"
        case .medium:
            return "Good - Slight performance reduction"
        case .low:
            return "Poor - Moderate performance reduction"
        case .critical:
            return "Critical - Aggressive performance reduction"
        }
    }
}

/**
 * Policy - Performance policy configuration
 * 
 * This struct defines what performance level the app should operate at.
 * It contains all the settings that control throttling behavior.
 */
public struct Policy: Sendable {
    /// Maximum number of concurrent network requests allowed
    public let maxNetworkConcurrent: Int
    
    /// Whether background machine learning is allowed
    public let allowBackgroundMl: Bool
    
    /// Recommended image quality for current conditions
    public let imageVariant: ImageVariant
    
    /// Whether to prefer cached data when device is unhealthy
    public let preferCacheWhenUnhealthy: Bool
    
    /// Overall health level this policy represents
    public let healthLevel: HealthLevel
    
    /**
     * Image quality variants for different performance levels.
     * 
     * During poor conditions, Kairo will recommend smaller images to save
     * bandwidth and processing power.
     */
    public enum ImageVariant: String, Sendable, CaseIterable {
        case original = "original"  // Full quality - best conditions
        case large = "large"        // High quality - good conditions
        case medium = "medium"      // Medium quality - fair conditions
        case small = "small"        // Low quality - poor conditions
        
        /**
         * Get the file size multiplier for this image variant.
         * Used to estimate bandwidth usage.
         */
        public var sizeMultiplier: Float {
            switch self {
            case .original: return 1.0
            case .large: return 0.6
            case .medium: return 0.3
            case .small: return 0.1
            }
        }
        
        /**
         * Get a human-readable description of this image quality.
         */
        public var description: String {
            switch self {
            case .original: return "Original quality"
            case .large: return "High quality"
            case .medium: return "Medium quality"
            case .small: return "Low quality"
            }
        }
    }
    
    /**
     * Initialize a new policy with all settings.
     * 
     * - Parameters:
     *   - maxNetworkConcurrent: Maximum concurrent network requests
     *   - allowBackgroundMl: Whether background ML is allowed
     *   - imageVariant: Recommended image quality
     *   - preferCacheWhenUnhealthy: Whether to prefer cache during poor conditions
     *   - healthLevel: The health level this policy represents
     */
    public init(
        maxNetworkConcurrent: Int,
        allowBackgroundMl: Bool,
        imageVariant: ImageVariant,
        preferCacheWhenUnhealthy: Bool,
        healthLevel: HealthLevel = .high
    ) {
        self.maxNetworkConcurrent = maxNetworkConcurrent
        self.allowBackgroundMl = allowBackgroundMl
        self.imageVariant = imageVariant
        self.preferCacheWhenUnhealthy = preferCacheWhenUnhealthy
        self.healthLevel = healthLevel
    }
}

/**
 * PolicyEngine - The intelligent decision maker for performance policies
 * 
 * This class analyzes device health and determines appropriate performance policies.
 * It uses a sophisticated scoring system that considers multiple factors to make
 * intelligent decisions about when and how to throttle performance.
 */
public class PolicyEngine {
    
    // MARK: - Properties
    
    /// Configuration settings for the policy engine
    private let config: KairoConfig
    
    /// Logger for debugging and monitoring
    private let logger: Logger
    
    /// Current policy being applied
    private var currentPolicy: Policy
    
    /// History of recent health scores for trend analysis
    private var healthScoreHistory: [Float] = []
    
    /// Maximum number of health scores to keep in history
    private let maxHistorySize = 10
    
    // MARK: - Initialization
    
    /**
     * Initialize the policy engine with configuration.
     * 
     * - Parameter config: Configuration settings for the policy engine
     * - Parameter logger: Logger instance for debugging
     * 
     * This creates a new PolicyEngine that will make decisions based on the
     * provided configuration and log its decisions for debugging.
     */
    public init(config: KairoConfig, logger: Logger) {
        self.config = config
        self.logger = logger
        
        // Start with a high-performance policy
        self.currentPolicy = Policy(
            maxNetworkConcurrent: config.networkMaxConcurrent,
            allowBackgroundMl: true,
            imageVariant: .original,
            preferCacheWhenUnhealthy: false,
            healthLevel: .high
        )
        
        logger.info("PolicyEngine initialized with config: \(config)")
    }
    
    // MARK: - Public Methods
    
    /**
     * Evaluate and return the appropriate policy for given health conditions.
     * 
     * - Parameter health: Current health snapshot from HealthMonitor
     * - Returns: A Policy object with appropriate settings for current conditions
     * 
     * This is the main method that analyzes health conditions and determines
     * what performance policy to apply. It considers multiple factors and uses
     * intelligent scoring to make decisions.
     */
    public func evaluatePolicy(for health: HealthSnapshot) -> Policy {
        // Calculate overall health score
        let healthScore = calculateHealthScore(from: health)
        
        // Update health score history for trend analysis
        updateHealthScoreHistory(healthScore)
        
        // Determine health level based on score and conditions
        let healthLevel = determineHealthLevel(score: healthScore, health: health)
        
        // Generate policy based on health level
        let policy = generatePolicy(for: healthLevel, health: health)
        
        // Log the decision for debugging
        logger.debug("Policy evaluated: healthScore=\(String(format: "%.2f", healthScore)), level=\(healthLevel), policy=\(policy)")
        
        return policy
    }
    
    /**
     * Check if a specific operation should be allowed based on current conditions.
     * 
     * - Parameter operation: The type of operation to check
     * - Parameter health: Current health snapshot
     * - Parameter currentPolicy: Current performance policy
     * - Returns: True if the operation should be allowed, false if it should be throttled
     * 
     * This method provides fine-grained control over individual operations.
     * It can make different decisions for different types of operations based
     * on current device conditions.
     */
    public func shouldAllowOperation(
        _ operation: OperationType,
        given health: HealthSnapshot,
        currentPolicy: Policy
    ) -> Bool {
        // Always allow critical operations
        if isCriticalOperation(operation) {
            return true
        }
        
        // Check if device is in critical state
        if health.isCritical {
            return shouldAllowInCriticalState(operation)
        }
        
        // Check thermal state restrictions
        if !shouldAllowForThermalState(operation, thermalState: health.thermalState) {
            logger.debug("Operation \(operation) blocked due to thermal state: \(health.thermalState)")
            return false
        }
        
        // Check battery level restrictions
        if !shouldAllowForBatteryLevel(operation, batteryLevel: health.batteryLevel) {
            logger.debug("Operation \(operation) blocked due to low battery: \(health.batteryLevel)")
            return false
        }
        
        // Check network restrictions
        if !shouldAllowForNetworkConditions(operation, health: health) {
            logger.debug("Operation \(operation) blocked due to network conditions")
            return false
        }
        
        // Check policy-specific restrictions
        if !shouldAllowForPolicy(operation, policy: currentPolicy) {
            logger.debug("Operation \(operation) blocked by current policy")
            return false
        }
        
        return true
    }
    
    // MARK: - Private Methods
    
    /**
     * Calculate a comprehensive health score from health snapshot.
     * 
     * - Parameter health: Health snapshot to analyze
     * - Returns: Health score from 0.0 (critical) to 1.0 (excellent)
     * 
     * This method combines all health factors into a single score that can be used
     * for policy decisions. It uses weighted factors to prioritize the most important
     * health indicators.
     */
    private func calculateHealthScore(from health: HealthSnapshot) -> Float {
        var score: Float = 1.0
        
        // Battery level is the most important factor (40% weight)
        let batteryScore = health.batteryLevel
        score *= (batteryScore * 0.4 + 0.6) // Ensure minimum score of 0.6
        
        // Thermal state is very important (30% weight)
        let thermalScore = thermalStateScore(health.thermalState)
        score *= (thermalScore * 0.3 + 0.7)
        
        // Low power mode affects performance (15% weight)
        if health.lowPowerMode {
            score *= 0.85
        }
        
        // Network conditions affect user experience (10% weight)
        let networkScore = networkConditionScore(health)
        score *= (networkScore * 0.1 + 0.9)
        
        // Network expense affects data usage (5% weight)
        if health.networkExpensive {
            score *= 0.95
        }
        
        return max(0.0, min(1.0, score))
    }
    
    /**
     * Convert thermal state to a numeric score.
     * 
     * - Parameter thermalState: Current thermal state
     * - Returns: Score from 0.0 (critical) to 1.0 (nominal)
     */
    private func thermalStateScore(_ thermalState: ProcessInfo.ThermalState) -> Float {
        switch thermalState {
        case .nominal:
            return 1.0
        case .fair:
            return 0.8
        case .serious:
            return 0.5
        case .critical:
            return 0.2
        @unknown default:
            return 0.5
        }
    }
    
    /**
     * Calculate network condition score.
     * 
     * - Parameter health: Health snapshot containing network info
     * - Returns: Network score from 0.0 (poor) to 1.0 (excellent)
     */
    private func networkConditionScore(_ health: HealthSnapshot) -> Float {
        var score: Float = 1.0
        
        // Network reachability
        switch health.networkReachability {
        case .satisfied:
            score = 1.0
        case .requiresConnection:
            score = 0.0
        case .satisfiable:
            score = 0.5
        @unknown default:
            score = 0.5
        }
        
        // Network constraints
        if health.networkConstrained {
            score *= 0.7
        }
        
        return score
    }
    
    /**
     * Update health score history for trend analysis.
     * 
     * - Parameter score: New health score to add to history
     * 
     * This method maintains a rolling history of health scores to detect
     * trends and make more intelligent decisions.
     */
    private func updateHealthScoreHistory(_ score: Float) {
        healthScoreHistory.append(score)
        
        // Keep only the most recent scores
        if healthScoreHistory.count > maxHistorySize {
            healthScoreHistory.removeFirst()
        }
    }
    
    /**
     * Determine health level based on score and conditions.
     * 
     * - Parameters:
     *   - score: Calculated health score
     *   - health: Health snapshot for additional context
     * - Returns: Appropriate HealthLevel for current conditions
     */
    private func determineHealthLevel(score: Float, health: HealthSnapshot) -> HealthLevel {
        // Critical conditions override score
        if health.isCritical {
            return .critical
        }
        
        // Use score thresholds with some hysteresis to prevent oscillation
        let currentLevel = currentPolicy.healthLevel
        
        switch currentLevel {
        case .high:
            if score < 0.7 {
                return .medium
            }
        case .medium:
            if score < 0.4 {
                return .low
            } else if score > 0.8 {
                return .high
            }
        case .low:
            if score < 0.2 {
                return .critical
            } else if score > 0.6 {
                return .medium
            }
        case .critical:
            if score > 0.4 {
                return .low
            }
        }
        
        return currentLevel
    }
    
    /**
     * Generate a policy for the given health level.
     * 
     * - Parameters:
     *   - healthLevel: The health level to generate policy for
     *   - health: Health snapshot for additional context
     * - Returns: A Policy object with appropriate settings
     */
    private func generatePolicy(for healthLevel: HealthLevel, health: HealthSnapshot) -> Policy {
        switch healthLevel {
        case .high:
            return Policy(
                maxNetworkConcurrent: config.networkMaxConcurrent,
                allowBackgroundMl: true,
                imageVariant: .original,
                preferCacheWhenUnhealthy: false,
                healthLevel: .high
            )
            
        case .medium:
            return Policy(
                maxNetworkConcurrent: max(2, config.networkMaxConcurrent / 2),
                allowBackgroundMl: true,
                imageVariant: .large,
                preferCacheWhenUnhealthy: false,
                healthLevel: .medium
            )
            
        case .low:
            return Policy(
                maxNetworkConcurrent: max(1, config.networkMaxConcurrent / 4),
                allowBackgroundMl: false,
                imageVariant: .medium,
                preferCacheWhenUnhealthy: true,
                healthLevel: .low
            )
            
        case .critical:
            return Policy(
                maxNetworkConcurrent: 1,
                allowBackgroundMl: false,
                imageVariant: .small,
                preferCacheWhenUnhealthy: true,
                healthLevel: .critical
            )
        }
    }
    
    /**
     * Check if an operation is critical and should always be allowed.
     * 
     * - Parameter operation: Operation to check
     * - Returns: True if the operation is critical
     */
    private func isCriticalOperation(_ operation: OperationType) -> Bool {
        switch operation {
        case .networkRequest(let priority):
            return priority == .critical
        case .imageProcessing, .machineLearningInference, .backgroundTask, .fileDownload, .videoProcessing:
            return false
        }
    }
    
    /**
     * Determine if an operation should be allowed in critical device state.
     * 
     * - Parameter operation: Operation to check
     * - Returns: True if the operation should be allowed
     */
    private func shouldAllowInCriticalState(_ operation: OperationType) -> Bool {
        switch operation {
        case .networkRequest(let priority):
            return priority == .critical
        case .imageProcessing, .machineLearningInference, .backgroundTask, .fileDownload, .videoProcessing:
            return false
        }
    }
    
    /**
     * Check if an operation should be allowed based on thermal state.
     * 
     * - Parameters:
     *   - operation: Operation to check
     *   - thermalState: Current thermal state
     * - Returns: True if the operation should be allowed
     */
    private func shouldAllowForThermalState(_ operation: OperationType, thermalState: ProcessInfo.ThermalState) -> Bool {
        switch thermalState {
        case .nominal, .fair:
            return true
        case .serious:
            // Block CPU-intensive operations
            switch operation {
            case .machineLearningInference, .videoProcessing:
                return false
            default:
                return true
            }
        case .critical:
            // Block most operations except critical network requests
            switch operation {
            case .networkRequest(let priority):
                return priority == .critical
            default:
                return false
            }
        @unknown default:
            return false
        }
    }
    
    /**
     * Check if an operation should be allowed based on battery level.
     * 
     * - Parameters:
     *   - operation: Operation to check
     *   - batteryLevel: Current battery level
     * - Returns: True if the operation should be allowed
     */
    private func shouldAllowForBatteryLevel(_ operation: OperationType, batteryLevel: Float) -> Bool {
        // Block expensive operations when battery is very low
        if batteryLevel < config.lowBatteryThreshold {
            switch operation {
            case .machineLearningInference, .videoProcessing, .fileDownload:
                return false
            default:
                return true
            }
        }
        
        return true
    }
    
    /**
     * Check if an operation should be allowed based on network conditions.
     * 
     * - Parameters:
     *   - operation: Operation to check
     *   - health: Health snapshot with network info
     * - Returns: True if the operation should be allowed
     */
    private func shouldAllowForNetworkConditions(_ operation: OperationType, health: HealthSnapshot) -> Bool {
        // Block network operations if no connectivity
        if health.networkReachability != .satisfied {
            switch operation {
            case .networkRequest, .fileDownload:
                return false
            default:
                return true
            }
        }
        
        // Reduce expensive operations on constrained networks
        if health.networkConstrained {
            switch operation {
            case .fileDownload(let size):
                return size < 10_000_000 // 10MB limit
            case .imageProcessing(let size):
                return size != .large
            default:
                return true
            }
        }
        
        return true
    }
    
    /**
     * Check if an operation should be allowed based on current policy.
     * 
     * - Parameters:
     *   - operation: Operation to check
     *   - policy: Current performance policy
     * - Returns: True if the operation should be allowed
     */
    private func shouldAllowForPolicy(_ operation: OperationType, policy: Policy) -> Bool {
        switch operation {
        case .machineLearningInference:
            return policy.allowBackgroundMl
        case .networkRequest:
            // This would need to be checked against current network request count
            // For now, assume it's allowed
            return true
        default:
            return true
        }
    }
}
