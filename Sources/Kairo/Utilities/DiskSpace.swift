import Foundation

/**
 * DiskSpace - Utility for monitoring and managing disk space
 * 
 * This class provides comprehensive disk space monitoring and management
 * capabilities. It can check available space, warn when space is low,
 * and help manage disk usage during poor device conditions.
 * 
 * Key features:
 * - Real-time disk space monitoring
 * - Low space warnings and alerts
 * - Disk usage analysis and recommendations
 * - Automatic cleanup suggestions
 */

/**
 * DiskSpaceInfo - Information about disk space usage
 * 
 * This struct contains comprehensive information about disk space usage,
 * including available space, used space, and usage percentages.
 */
public struct DiskSpaceInfo: Sendable {
    /// Total disk space in bytes
    public let totalSpace: Int64
    
    /// Available disk space in bytes
    public let availableSpace: Int64
    
    /// Used disk space in bytes
    public let usedSpace: Int64
    
    /// Available space as a percentage (0.0 to 1.0)
    public let availablePercentage: Double
    
    /// Used space as a percentage (0.0 to 1.0)
    public let usedPercentage: Double
    
    /// Whether the disk is critically low on space
    public let isLowSpace: Bool
    
    /// Whether the disk is critically low on space
    public let isCriticalSpace: Bool
    
    /// Timestamp when this information was gathered
    public let timestamp: Date
    
    /**
     * Initialize disk space information with all values
     * 
     * - Parameters:
     *   - totalSpace: Total disk space in bytes
     *   - availableSpace: Available disk space in bytes
     *   - usedSpace: Used disk space in bytes
     *   - availablePercentage: Available space percentage
     *   - usedPercentage: Used space percentage
     *   - isLowSpace: Whether space is low
     *   - isCriticalSpace: Whether space is critically low
     *   - timestamp: When this information was gathered
     */
    public init(
        totalSpace: Int64,
        availableSpace: Int64,
        usedSpace: Int64,
        availablePercentage: Double,
        usedPercentage: Double,
        isLowSpace: Bool,
        isCriticalSpace: Bool,
        timestamp: Date = Date()
    ) {
        self.totalSpace = totalSpace
        self.availableSpace = availableSpace
        self.usedSpace = usedSpace
        self.availablePercentage = availablePercentage
        self.usedPercentage = usedPercentage
        self.isLowSpace = isLowSpace
        self.isCriticalSpace = isCriticalSpace
        self.timestamp = timestamp
    }
    
    /**
     * Get a human-readable description of available space
     * 
     * - Returns: Formatted string describing available space
     * 
     * Example: "2.5 GB available (25% of 10 GB total)"
     */
    public var availableSpaceDescription: String {
        let availableGB = Double(availableSpace) / (1024 * 1024 * 1024)
        let totalGB = Double(totalSpace) / (1024 * 1024 * 1024)
        let percentage = availablePercentage * 100
        
        return String(format: "%.1f GB available (%.0f%% of %.1f GB total)",
                     availableGB, percentage, totalGB)
    }
    
    /**
     * Get a human-readable description of used space
     * 
     * - Returns: Formatted string describing used space
     * 
     * Example: "7.5 GB used (75% of 10 GB total)"
     */
    public var usedSpaceDescription: String {
        let usedGB = Double(usedSpace) / (1024 * 1024 * 1024)
        let totalGB = Double(totalSpace) / (1024 * 1024 * 1024)
        let percentage = usedPercentage * 100
        
        return String(format: "%.1f GB used (%.0f%% of %.1f GB total)",
                     usedGB, percentage, totalGB)
    }
}

/**
 * DiskSpaceThresholds - Configuration for disk space warnings
 * 
 * This struct defines the thresholds for low space and critical space warnings.
 * You can customize these values based on your app's needs.
 */
public struct DiskSpaceThresholds: Sendable {
    /// Percentage threshold for low space warning (0.0 to 1.0)
    public let lowSpaceThreshold: Double
    
    /// Percentage threshold for critical space warning (0.0 to 1.0)
    public let criticalSpaceThreshold: Double
    
    /// Minimum absolute space required in bytes
    public let minimumAbsoluteSpace: Int64
    
    /**
     * Initialize disk space thresholds
     * 
     * - Parameters:
     *   - lowSpaceThreshold: Percentage for low space warning (default: 0.15 = 15%)
     *   - criticalSpaceThreshold: Percentage for critical space warning (default: 0.05 = 5%)
     *   - minimumAbsoluteSpace: Minimum absolute space in bytes (default: 1 GB)
     */
    public init(
        lowSpaceThreshold: Double = 0.15,
        criticalSpaceThreshold: Double = 0.05,
        minimumAbsoluteSpace: Int64 = 1_073_741_824 // 1 GB
    ) {
        self.lowSpaceThreshold = lowSpaceThreshold
        self.criticalSpaceThreshold = criticalSpaceThreshold
        self.minimumAbsoluteSpace = minimumAbsoluteSpace
    }
    
    /// Default thresholds for most use cases
    public static let `default` = DiskSpaceThresholds()
}

/**
 * DiskSpace - Main class for disk space monitoring and management
 * 
 * This class provides comprehensive disk space monitoring capabilities.
 * It can check current disk usage, warn about low space, and provide
 * recommendations for freeing up space.
 */
public class DiskSpace: ObservableObject {
    
    // MARK: - Properties
    
    /// Current disk space information
    @Published public private(set) var currentInfo: DiskSpaceInfo?
    
    /// Configuration thresholds for warnings
    private let thresholds: DiskSpaceThresholds
    
    /// Logger for debugging and monitoring
    private let logger: Logger
    
    /// Timer for periodic disk space checks
    private var monitoringTimer: Timer?
    
    /// Whether monitoring is currently active
    private var isMonitoring: Bool = false
    
    // MARK: - Initialization
    
    /**
     * Initialize disk space monitor with configuration
     * 
     * - Parameters:
     *   - thresholds: Configuration for space warnings
     *   - logger: Logger instance for debugging
     * 
     * This creates a new DiskSpace monitor that will track disk usage
     * and provide warnings when space becomes low.
     */
    public init(thresholds: DiskSpaceThresholds = .default, logger: Logger) {
        self.thresholds = thresholds
        self.logger = logger
        
        logger.info("DiskSpace monitor initialized with thresholds: \(thresholds)")
    }
    
    // MARK: - Public Methods
    
    /**
     * Get current disk space information
     * 
     * - Returns: Current disk space information
     * - Throws: DiskSpaceError if unable to get disk information
     * 
     * This method provides immediate access to current disk space information.
     * It's useful for one-time checks or when you need current information.
     * 
     * Usage:
     * ```swift
     * do {
     *     let info = try await diskSpace.getCurrentInfo()
     *     print("Available space: \(info.availableSpaceDescription)")
     * } catch {
     *     print("Failed to get disk space info: \(error)")
     * }
     * ```
     */
    public func getCurrentInfo() async throws -> DiskSpaceInfo {
        let info = try await gatherDiskSpaceInfo()
        currentInfo = info
        return info
    }
    
    /**
     * Start monitoring disk space with periodic checks
     * 
     * - Parameter interval: How often to check disk space (default: 30 seconds)
     * 
     * This method begins continuous monitoring of disk space. It will
     * check disk usage at regular intervals and update the currentInfo
     * property with the latest information.
     * 
     * The monitoring will automatically detect low space conditions and
     * log warnings when thresholds are exceeded.
     */
    public func startMonitoring(interval: TimeInterval = 30.0) async {
        guard !isMonitoring else {
            logger.warning("Disk space monitoring is already running")
            return
        }
        
        logger.info("Starting disk space monitoring with interval: \(interval)s")
        isMonitoring = true
        
        // Take initial reading
        do {
            let info = try await getCurrentInfo()
            await checkSpaceThresholds(info)
        } catch {
            logger.error("Failed to get initial disk space info: \(error)")
        }
        
        // Start periodic monitoring
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performPeriodicCheck()
            }
        }
    }
    
    /**
     * Stop monitoring disk space
     * 
     * This method stops the periodic disk space monitoring and cleans up
     * the monitoring timer. Call this when you no longer need monitoring.
     */
    public func stopMonitoring() async {
        guard isMonitoring else {
            logger.warning("Disk space monitoring is not running")
            return
        }
        
        logger.info("Stopping disk space monitoring...")
        isMonitoring = false
        
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        logger.info("Disk space monitoring stopped")
    }
    
    /**
     * Check if disk space is critically low
     * 
     * - Returns: True if disk space is critically low
     * 
     * This method provides a quick way to check if the disk is critically
     * low on space. It's useful for making immediate decisions about
     * whether to allow certain operations.
     */
    public func isCriticallyLow() -> Bool {
        return currentInfo?.isCriticalSpace ?? false
    }
    
    /**
     * Check if disk space is low (but not critical)
     * 
     * - Returns: True if disk space is low
     * 
     * This method provides a quick way to check if the disk is low on space.
     * It's useful for making decisions about whether to allow certain operations.
     */
    public func isLow() -> Bool {
        return currentInfo?.isLowSpace ?? false
    }
    
    /**
     * Get recommendations for freeing up disk space
     * 
     * - Returns: Array of recommendations for freeing up space
     * 
     * This method analyzes current disk usage and provides recommendations
     * for freeing up space. It considers various factors like available
     * space, usage patterns, and system capabilities.
     */
    public func getSpaceRecommendations() async -> [SpaceRecommendation] {
        guard let info = currentInfo else {
            return [SpaceRecommendation(
                type: .unknown,
                description: "Unable to get disk space information",
                estimatedSpace: 0,
                priority: .low
            )]
        }
        
        var recommendations: [SpaceRecommendation] = []
        
        // Add recommendations based on available space
        if info.availablePercentage < thresholds.criticalSpaceThreshold {
            recommendations.append(SpaceRecommendation(
                type: .critical,
                description: "Disk space is critically low. Free up space immediately.",
                estimatedSpace: 0,
                priority: .critical
            ))
        } else if info.availablePercentage < thresholds.lowSpaceThreshold {
            recommendations.append(SpaceRecommendation(
                type: .warning,
                description: "Disk space is low. Consider freeing up space.",
                estimatedSpace: 0,
                priority: .high
            ))
        }
        
        // Add specific recommendations based on available space
        let availableGB = Double(info.availableSpace) / (1024 * 1024 * 1024)
        
        if availableGB < 1.0 {
            recommendations.append(SpaceRecommendation(
                type: .cleanup,
                description: "Clear app caches and temporary files",
                estimatedSpace: 500_000_000, // 500 MB
                priority: .high
            ))
        }
        
        if availableGB < 2.0 {
            recommendations.append(SpaceRecommendation(
                type: .cleanup,
                description: "Delete unused downloads and documents",
                estimatedSpace: 1_000_000_000, // 1 GB
                priority: .medium
            ))
        }
        
        return recommendations
    }
    
    // MARK: - Private Methods
    
    /**
     * Gather current disk space information from the system
     * 
     * - Returns: Current disk space information
     * - Throws: DiskSpaceError if unable to get disk information
     * 
     * This method queries the system for current disk space information
     * and calculates all the relevant metrics.
     */
    private func gatherDiskSpaceInfo() async throws -> DiskSpaceInfo {
        // Get the documents directory as a reference point
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let documentsURL = URL(fileURLWithPath: documentsPath)
        
        // Get file system attributes
        let resourceValues = try documentsURL.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey
        ])
        
        guard let totalCapacity = resourceValues.volumeTotalCapacity,
              let availableCapacity = resourceValues.volumeAvailableCapacity else {
            throw DiskSpaceError.unableToGetDiskInfo
        }
        
        let totalSpace = Int64(totalCapacity)
        let availableSpace = Int64(availableCapacity)
        let usedSpace = totalSpace - availableSpace
        
        let availablePercentage = Double(availableSpace) / Double(totalSpace)
        let usedPercentage = Double(usedSpace) / Double(totalSpace)
        
        // Check if space is low or critical
        let isLowSpace = availablePercentage < thresholds.lowSpaceThreshold || availableSpace < thresholds.minimumAbsoluteSpace
        let isCriticalSpace = availablePercentage < thresholds.criticalSpaceThreshold || availableSpace < (thresholds.minimumAbsoluteSpace / 2)
        
        return DiskSpaceInfo(
            totalSpace: totalSpace,
            availableSpace: availableSpace,
            usedSpace: usedSpace,
            availablePercentage: availablePercentage,
            usedPercentage: usedPercentage,
            isLowSpace: isLowSpace,
            isCriticalSpace: isCriticalSpace
        )
    }
    
    /**
     * Perform a periodic disk space check
     * 
     * This method is called by the monitoring timer to check disk space
     * at regular intervals. It updates the current information and
     * checks for threshold violations.
     */
    private func performPeriodicCheck() async {
        do {
            let info = try await getCurrentInfo()
            await checkSpaceThresholds(info)
        } catch {
            logger.error("Failed to perform periodic disk space check: \(error)")
        }
    }
    
    /**
     * Check disk space thresholds and log warnings if needed
     * 
     * - Parameter info: Current disk space information
     * 
     * This method analyzes the current disk space information and
     * logs appropriate warnings if thresholds are exceeded.
     */
    private func checkSpaceThresholds(_ info: DiskSpaceInfo) async {
        if info.isCriticalSpace {
            logger.warning("CRITICAL: Disk space is critically low - \(info.availableSpaceDescription)")
        } else if info.isLowSpace {
            logger.warning("WARNING: Disk space is low - \(info.availableSpaceDescription)")
        } else {
            logger.debug("Disk space is adequate - \(info.availableSpaceDescription)")
        }
    }
}

/**
 * SpaceRecommendation - A recommendation for freeing up disk space
 * 
 * This struct represents a specific recommendation for freeing up disk space.
 * It includes the type of recommendation, description, estimated space savings,
 * and priority level.
 */
public struct SpaceRecommendation: Sendable {
    /// Type of recommendation
    public let type: RecommendationType
    
    /// Human-readable description of the recommendation
    public let description: String
    
    /// Estimated space that could be freed (in bytes)
    public let estimatedSpace: Int64
    
    /// Priority level for this recommendation
    public let priority: Priority
    
    /**
     * Types of space recommendations
     */
    public enum RecommendationType: Sendable {
        case cleanup      // General cleanup recommendation
        case warning     // Warning about low space
        case critical     // Critical space situation
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
 * DiskSpaceError - Errors that can occur when working with disk space
 * 
 * This enum defines all the possible errors that can occur when
 * monitoring or managing disk space.
 */
public enum DiskSpaceError: Error, Sendable {
    case unableToGetDiskInfo
    case invalidPath
    case insufficientPermissions
    case monitoringAlreadyActive
    case monitoringNotActive
    
    /**
     * Get a human-readable description of this error
     */
    public var description: String {
        switch self {
        case .unableToGetDiskInfo:
            return "Unable to get disk space information"
        case .invalidPath:
            return "Invalid file path provided"
        case .insufficientPermissions:
            return "Insufficient permissions to access disk information"
        case .monitoringAlreadyActive:
            return "Disk space monitoring is already active"
        case .monitoringNotActive:
            return "Disk space monitoring is not active"
        }
    }
}
