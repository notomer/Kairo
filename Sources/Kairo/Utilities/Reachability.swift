import Foundation
import Network

/**
 * Reachability - Network connectivity monitoring and management
 * 
 * This class provides comprehensive network connectivity monitoring capabilities.
 * It can detect network changes, monitor connection quality, and provide
 * recommendations for network usage during poor conditions.
 * 
 * Key features:
 * - Real-time network connectivity monitoring
 * - Connection quality assessment
 * - Network type detection (WiFi, Cellular, etc.)
 * - Automatic reconnection handling
 * - Network usage recommendations
 */

/**
 * NetworkStatus - Current network connectivity status
 * 
 * This struct contains comprehensive information about the current network
 * connectivity, including connection type, quality, and availability.
 */
public struct NetworkStatus: Sendable {
    /// Whether the device has network connectivity
    public let isConnected: Bool
    
    /// Type of network connection
    public let connectionType: ConnectionType
    
    /// Quality of the network connection
    public let quality: ConnectionQuality
    
    /// Whether the connection is expensive (cellular data)
    public let isExpensive: Bool
    
    /// Whether the connection is constrained (slow/congested)
    public let isConstrained: Bool
    
    /// Whether the connection requires user intervention
    public let requiresConnection: Bool
    
    /// Timestamp when this status was determined
    public let timestamp: Date
    
    /**
     * Types of network connections
     */
    public enum ConnectionType: Sendable {
        case none           // No network connection
        case wifi           // WiFi connection
        case cellular       // Cellular data connection
        case ethernet       // Ethernet connection
        case other          // Other type of connection
        case unknown        // Unknown connection type
        
        /**
         * Get a human-readable description of this connection type
         */
        public var description: String {
            switch self {
            case .none: return "No Connection"
            case .wifi: return "WiFi"
            case .cellular: return "Cellular"
            case .ethernet: return "Ethernet"
            case .other: return "Other"
            case .unknown: return "Unknown"
            }
        }
    }
    
    /**
     * Quality levels for network connections
     */
    public enum ConnectionQuality: Sendable {
        case excellent      // Excellent connection quality
        case good          // Good connection quality
        case fair          // Fair connection quality
        case poor          // Poor connection quality
        case unknown       // Unknown quality
        
        /**
         * Get a human-readable description of this quality level
         */
        public var description: String {
            switch self {
            case .excellent: return "Excellent"
            case .good: return "Good"
            case .fair: return "Fair"
            case .poor: return "Poor"
            case .unknown: return "Unknown"
            }
        }
        
        /**
         * Get a numeric score for this quality level (0.0 to 1.0)
         */
        public var score: Double {
            switch self {
            case .excellent: return 1.0
            case .good: return 0.8
            case .fair: return 0.6
            case .poor: return 0.3
            case .unknown: return 0.5
            }
        }
    }
    
    /**
     * Initialize network status with all values
     * 
     * - Parameters:
     *   - isConnected: Whether the device has network connectivity
     *   - connectionType: Type of network connection
     *   - quality: Quality of the network connection
     *   - isExpensive: Whether the connection is expensive
     *   - isConstrained: Whether the connection is constrained
     *   - requiresConnection: Whether the connection requires user intervention
     *   - timestamp: When this status was determined
     */
    public init(
        isConnected: Bool,
        connectionType: ConnectionType,
        quality: ConnectionQuality,
        isExpensive: Bool,
        isConstrained: Bool,
        requiresConnection: Bool,
        timestamp: Date = Date()
    ) {
        self.isConnected = isConnected
        self.connectionType = connectionType
        self.quality = quality
        self.isExpensive = isExpensive
        self.isConstrained = isConstrained
        self.requiresConnection = requiresConnection
        self.timestamp = timestamp
    }
    
    /**
     * Get a human-readable description of the current network status
     * 
     * - Returns: Formatted string describing the network status
     * 
     * Example: "WiFi - Good Quality (Constrained)"
     */
    public var statusDescription: String {
        var description = connectionType.description
        
        if isConnected {
            description += " - \(quality.description) Quality"
            
            if isConstrained {
                description += " (Constrained)"
            }
            
            if isExpensive {
                description += " (Expensive)"
            }
        } else {
            description += " - No Connection"
        }
        
        return description
    }
}

/**
 * Reachability - Main class for network connectivity monitoring
 * 
 * This class provides comprehensive network connectivity monitoring capabilities.
 * It can detect network changes, monitor connection quality, and provide
 * recommendations for network usage during poor conditions.
 */
public class Reachability: ObservableObject {
    
    // MARK: - Properties
    
    /// Current network status
    @Published public private(set) var currentStatus: NetworkStatus?
    
    /// Network path monitor for detecting changes
    private var pathMonitor: NWPathMonitor?
    
    /// Logger for debugging and monitoring
    private let logger: Logger
    
    /// Whether monitoring is currently active
    private var isMonitoring: Bool = false
    
    /// Continuations for async streams
    private var statusContinuations: [UUID: AsyncStream<NetworkStatus>.Continuation] = [:]
    
    // MARK: - Initialization
    
    /**
     * Initialize network reachability monitor
     * 
     * - Parameter logger: Logger instance for debugging
     * 
     * This creates a new Reachability monitor that will track network
     * connectivity and provide status updates.
     */
    public init(logger: Logger) {
        self.logger = logger
        logger.info("Reachability monitor initialized")
    }
    
    // MARK: - Public Methods
    
    /**
     * Start monitoring network connectivity
     * 
     * This method begins continuous monitoring of network connectivity.
     * It will detect network changes and update the currentStatus property
     * with the latest information.
     * 
     * The monitoring will automatically detect network changes and
     * log status updates when connectivity changes.
     */
    public func startMonitoring() async {
        guard !isMonitoring else {
            logger.warning("Network monitoring is already running")
            return
        }
        
        logger.info("Starting network connectivity monitoring...")
        isMonitoring = true
        
        // Create network path monitor
        pathMonitor = NWPathMonitor()
        
        // Set up path update handler
        pathMonitor?.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                await self?.handlePathUpdate(path)
            }
        }
        
        // Start monitoring on a background queue
        let queue = DispatchQueue(label: "com.kairo.network.monitor")
        pathMonitor?.start(queue: queue)
        
        // Take initial reading
        if let path = pathMonitor?.currentPath {
            await handlePathUpdate(path)
        }
        
        logger.info("Network connectivity monitoring started")
    }
    
    /**
     * Stop monitoring network connectivity
     * 
     * This method stops the network connectivity monitoring and cleans up
     * the monitoring resources. Call this when you no longer need monitoring.
     */
    public func stopMonitoring() async {
        guard isMonitoring else {
            logger.warning("Network monitoring is not running")
            return
        }
        
        logger.info("Stopping network connectivity monitoring...")
        isMonitoring = false
        
        // Stop path monitor
        pathMonitor?.cancel()
        pathMonitor = nil
        
        // Cancel all continuations
        for continuation in statusContinuations.values {
            continuation.finish()
        }
        statusContinuations.removeAll()
        
        logger.info("Network connectivity monitoring stopped")
    }
    
    /**
     * Get current network status
     * 
     * - Returns: Current network status information
     * - Throws: ReachabilityError if unable to get network information
     * 
     * This method provides immediate access to current network status.
     * It's useful for one-time checks or when you need current information.
     * 
     * Usage:
     * ```swift
     * do {
     *     let status = try await reachability.getCurrentStatus()
     *     print("Network status: \(status.statusDescription)")
     * } catch {
     *     print("Failed to get network status: \(error)")
     * }
     * ```
     */
    public func getCurrentStatus() async throws -> NetworkStatus {
        guard let pathMonitor = pathMonitor else {
            throw ReachabilityError.monitoringNotActive
        }
        
        let path = pathMonitor.currentPath
        return try await analyzeNetworkPath(path)
    }
    
    /**
     * Create an async stream of network status updates
     * 
     * - Returns: An AsyncStream that emits NetworkStatus objects when connectivity changes
     * 
     * This is the main way to subscribe to network status updates. The stream will emit
     * a new NetworkStatus whenever network conditions change.
     * 
     * Usage:
     * ```swift
     * for await status in reachability.statusStream() {
     *     // React to network changes
     * }
     * ```
     */
    public func statusStream() -> AsyncStream<NetworkStatus> {
        return AsyncStream { continuation in
            let id = UUID()
            statusContinuations[id] = continuation
            
            // Send current status immediately if available
            if let currentStatus = currentStatus {
                continuation.yield(currentStatus)
            }
            
            // Clean up when the stream ends
            continuation.onTermination = { _ in
                Task { @MainActor in
                    self.statusContinuations.removeValue(forKey: id)
                }
            }
        }
    }
    
    /**
     * Check if the device currently has network connectivity
     * 
     * - Returns: True if the device has network connectivity
     * 
     * This method provides a quick way to check if the device is connected
     * to the network. It's useful for making immediate decisions about
     * whether to allow certain operations.
     */
    public func isConnected() -> Bool {
        return currentStatus?.isConnected ?? false
    }
    
    /**
     * Check if the current connection is expensive (cellular data)
     * 
     * - Returns: True if the connection is expensive
     * 
     * This method provides a quick way to check if the current connection
     * is expensive. It's useful for making decisions about whether to
     * allow data-intensive operations.
     */
    public func isExpensive() -> Bool {
        return currentStatus?.isExpensive ?? false
    }
    
    /**
     * Check if the current connection is constrained (slow/congested)
     * 
     * - Returns: True if the connection is constrained
     * 
     * This method provides a quick way to check if the current connection
     * is constrained. It's useful for making decisions about whether to
     * allow bandwidth-intensive operations.
     */
    public func isConstrained() -> Bool {
        return currentStatus?.isConstrained ?? false
    }
    
    /**
     * Get recommendations for network usage based on current conditions
     * 
     * - Returns: Array of recommendations for network usage
     * 
     * This method analyzes current network conditions and provides recommendations
     * for network usage. It considers factors like connection type, quality,
     * and cost to provide intelligent suggestions.
     */
    public func getNetworkRecommendations() async -> [NetworkRecommendation] {
        guard let status = currentStatus else {
            return [NetworkRecommendation(
                type: .unknown,
                description: "Unable to get network status information",
                priority: .low
            )]
        }
        
        var recommendations: [NetworkRecommendation] = []
        
        // Add recommendations based on connection status
        if !status.isConnected {
            recommendations.append(NetworkRecommendation(
                type: .critical,
                description: "No network connection available. Check your internet connection.",
                priority: .critical
            ))
        } else {
            // Add recommendations based on connection quality
            switch status.quality {
            case .poor:
                recommendations.append(NetworkRecommendation(
                    type: .warning,
                    description: "Network connection is poor. Consider reducing data usage.",
                    priority: .high
                ))
            case .fair:
                recommendations.append(NetworkRecommendation(
                    type: .info,
                    description: "Network connection is fair. Monitor data usage.",
                    priority: .medium
                ))
            case .good, .excellent:
                // Good connection, no specific recommendations needed
                break
            case .unknown:
                recommendations.append(NetworkRecommendation(
                    type: .info,
                    description: "Network connection quality is unknown. Monitor performance.",
                    priority: .low
                ))
            }
            
            // Add recommendations based on connection type
            if status.isExpensive {
                recommendations.append(NetworkRecommendation(
                    type: .warning,
                    description: "Using expensive cellular data. Consider reducing data usage.",
                    priority: .high
                ))
            }
            
            if status.isConstrained {
                recommendations.append(NetworkRecommendation(
                    type: .info,
                    description: "Network connection is constrained. Consider reducing bandwidth usage.",
                    priority: .medium
                ))
            }
        }
        
        return recommendations
    }
    
    // MARK: - Private Methods
    
    /**
     * Handle network path updates from the system
     * 
     * - Parameter path: The current network path information
     * 
     * This method is called whenever network conditions change. It analyzes
     * the new path information and updates the current status.
     */
    private func handlePathUpdate(_ path: NWPath) async {
        do {
            let newStatus = try await analyzeNetworkPath(path)
            
            // Check if this is a significant change
            if let currentStatus = currentStatus {
                let significantChange = hasSignificantStatusChange(from: currentStatus, to: newStatus)
                if significantChange {
                    logger.info("Significant network change detected: \(newStatus.statusDescription)")
                }
            } else {
                logger.info("Initial network status: \(newStatus.statusDescription)")
            }
            
            // Update current status
            currentStatus = newStatus
            
            // Notify all subscribers
            for continuation in statusContinuations.values {
                continuation.yield(newStatus)
            }
            
        } catch {
            logger.error("Failed to analyze network path: \(error)")
        }
    }
    
    /**
     * Analyze network path and determine status
     * 
     * - Parameter path: The network path to analyze
     * - Returns: Network status information
     * - Throws: ReachabilityError if unable to analyze the path
     * 
     * This method analyzes the network path and determines the current
     * network status, including connection type, quality, and constraints.
     */
    private func analyzeNetworkPath(_ path: NWPath) async throws -> NetworkStatus {
        // Determine basic connectivity
        let isConnected = path.status == .satisfied
        let requiresConnection = path.status == .requiresConnection
        
        // Determine connection type
        let connectionType = determineConnectionType(path)
        
        // Determine connection quality
        let quality = determineConnectionQuality(path)
        
        // Check for constraints and expenses
        let isExpensive = path.isExpensive
        let isConstrained = path.isConstrained
        
        return NetworkStatus(
            isConnected: isConnected,
            connectionType: connectionType,
            quality: quality,
            isExpensive: isExpensive,
            isConstrained: isConstrained,
            requiresConnection: requiresConnection
        )
    }
    
    /**
     * Determine the type of network connection
     * 
     * - Parameter path: The network path to analyze
     * - Returns: The type of network connection
     * 
     * This method analyzes the network path to determine what type of
     * connection is being used (WiFi, cellular, etc.).
     */
    private func determineConnectionType(_ path: NWPath) -> NetworkStatus.ConnectionType {
        // Check for WiFi connection
        if path.usesInterfaceType(.wifi) {
            return .wifi
        }
        
        // Check for cellular connection
        if path.usesInterfaceType(.cellular) {
            return .cellular
        }
        
        // Check for ethernet connection
        if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        }
        
        // Check for other interface types
        if path.usesInterfaceType(.other) {
            return .other
        }
        
        // If no specific interface type is detected
        if path.status == .satisfied {
            return .unknown
        }
        
        return .none
    }
    
    /**
     * Determine the quality of the network connection
     * 
     * - Parameter path: The network path to analyze
     * - Returns: The quality of the network connection
     * 
     * This method analyzes the network path to determine the quality
     * of the connection based on various factors.
     */
    private func determineConnectionQuality(_ path: NWPath) -> NetworkStatus.ConnectionQuality {
        // If not connected, quality is unknown
        guard path.status == .satisfied else {
            return .unknown
        }
        
        // Start with good quality
        var quality = NetworkStatus.ConnectionQuality.good
        
        // Reduce quality for constrained connections
        if path.isConstrained {
            quality = .fair
        }
        
        // Further reduce quality for expensive connections
        if path.isExpensive {
            quality = .poor
        }
        
        // Check for multiple interface types (redundancy)
        let interfaceTypes = path.availableInterfaces
        if interfaceTypes.count > 1 {
            quality = .excellent
        }
        
        return quality
    }
    
    /**
     * Check if there's been a significant network status change
     * 
     * - Parameters:
     *   - from: Previous network status
     *   - to: Current network status
     * - Returns: True if the change is significant
     * 
     * This method determines whether a network status change is significant
     * enough to warrant notification and logging.
     */
    private func hasSignificantStatusChange(from previous: NetworkStatus, to current: NetworkStatus) -> Bool {
        // Connection status changed
        if previous.isConnected != current.isConnected {
            return true
        }
        
        // Connection type changed
        if previous.connectionType != current.connectionType {
            return true
        }
        
        // Connection quality changed significantly
        if abs(previous.quality.score - current.quality.score) > 0.2 {
            return true
        }
        
        // Expensive status changed
        if previous.isExpensive != current.isExpensive {
            return true
        }
        
        // Constrained status changed
        if previous.isConstrained != current.isConstrained {
            return true
        }
        
        return false
    }
}

/**
 * NetworkRecommendation - A recommendation for network usage
 * 
 * This struct represents a specific recommendation for network usage based on
 * current network conditions. It includes the type of recommendation,
 * description, and priority level.
 */
public struct NetworkRecommendation: Sendable {
    /// Type of recommendation
    public let type: RecommendationType
    
    /// Human-readable description of the recommendation
    public let description: String
    
    /// Priority level for this recommendation
    public let priority: Priority
    
    /**
     * Types of network recommendations
     */
    public enum RecommendationType: Sendable {
        case info        // Informational recommendation
        case warning     // Warning about network conditions
        case critical     // Critical network situation
        case unknown      // Unknown or error state
    }
    
    /**
     * Priority levels for recommendations
     */
    public enum Priority: Int, Sendable, CaseIterable {
        case low = 1
        case medium = 2
        case high = 3
        case critical = 4
        
        /**
         * Get a human-readable description of this priority
         */
        public var description: String {
            switch self {
            case .low: return "Low Priority"
            case .medium: return "Medium Priority"
            case .high: return "High Priority"
            case .critical: return "Critical Priority"
            }
        }
    }
}

/**
 * ReachabilityError - Errors that can occur when working with network reachability
 * 
 * This enum defines all the possible errors that can occur when
 * monitoring or managing network connectivity.
 */
public enum ReachabilityError: Error, Sendable {
    case monitoringNotActive
    case unableToGetNetworkInfo
    case invalidPath
    case monitoringAlreadyActive
    
    /**
     * Get a human-readable description of this error
     */
    public var description: String {
        switch self {
        case .monitoringNotActive:
            return "Network monitoring is not active"
        case .unableToGetNetworkInfo:
            return "Unable to get network information"
        case .invalidPath:
            return "Invalid network path provided"
        case .monitoringAlreadyActive:
            return "Network monitoring is already active"
        }
    }
}
