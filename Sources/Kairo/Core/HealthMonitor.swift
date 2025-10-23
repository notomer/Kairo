import Foundation
import Network
import UIKit

/**
 * HealthSnapshot - A comprehensive snapshot of device health conditions
 * 
 * This struct contains all the information Kairo needs to make intelligent
 * performance decisions. It's designed to be thread-safe (Sendable) so it
 * can be passed between different parts of the system safely.
 */
public struct HealthSnapshot: Sendable {
    /// Current battery level as a percentage (0.0 to 1.0)
    public var batteryLevel: Float
    
    /// Whether the device is in low power mode (user enabled)
    public var lowPowerMode: Bool
    
    /// Current thermal state of the device (how hot it is)
    public var thermalState: ProcessInfo.ThermalState
    
    /// Current network connectivity status
    public var networkReachability: NWPath.Status
    
    /// Whether the network connection is constrained (slow/congested)
    public var networkConstrained: Bool
    
    /// Whether the network connection is expensive (cellular data)
    public var networkExpensive: Bool
    
    /// Timestamp when this snapshot was taken
    public var timestamp: Date
    
    /**
     * Initialize a health snapshot with all the device information.
     * 
     * - Parameters:
     *   - batteryLevel: Battery percentage (0.0 to 1.0)
     *   - lowPowerMode: Whether low power mode is enabled
     *   - thermalState: Current thermal state of the device
     *   - networkReachability: Network connectivity status
     *   - networkConstrained: Whether network is slow/congested
     *   - networkExpensive: Whether using expensive cellular data
     */
    public init(
        batteryLevel: Float,
        lowPowerMode: Bool,
        thermalState: ProcessInfo.ThermalState,
        networkReachability: NWPath.Status,
        networkConstrained: Bool,
        networkExpensive: Bool,
        timestamp: Date = Date()
    ) {
        self.batteryLevel = batteryLevel
        self.lowPowerMode = lowPowerMode
        self.thermalState = thermalState
        self.networkReachability = networkReachability
        self.networkConstrained = networkConstrained
        self.networkExpensive = networkExpensive
        self.timestamp = timestamp
    }
    
    /**
     * Calculate an overall health score from 0.0 (critical) to 1.0 (excellent).
     * 
     * This combines all the health factors into a single score that can be used
     * for quick health assessments and comparisons.
     * 
     * - Returns: A health score between 0.0 and 1.0
     */
    public var overallHealthScore: Float {
        var score: Float = 1.0
        
        // Battery level contributes significantly to health score
        // Lower battery = lower score
        score *= batteryLevel
        
        // Low power mode reduces available performance
        if lowPowerMode {
            score *= 0.7
        }
        
        // Thermal state affects performance significantly
        switch thermalState {
        case .nominal:
            // Perfect thermal conditions
            break
        case .fair:
            // Slightly warm, reduce score slightly
            score *= 0.9
        case .serious:
            // Getting hot, reduce score more
            score *= 0.6
        case .critical:
            // Very hot, significantly reduce score
            score *= 0.3
        @unknown default:
            // Handle future thermal states
            score *= 0.5
        }
        
        // Network conditions affect user experience
        if networkConstrained {
            score *= 0.8
        }
        
        if networkExpensive {
            score *= 0.9
        }
        
        return max(0.0, min(1.0, score))
    }
    
    /**
     * Check if the device is in a critical state that requires immediate throttling.
     * 
     * - Returns: True if the device needs immediate performance reduction
     */
    public var isCritical: Bool {
        return batteryLevel < 0.05 || // Less than 5% battery
               thermalState == .critical || // Critical thermal state
               networkReachability == .requiresConnection // No network
    }
}

/**
 * HealthMonitor - Monitors device health conditions and provides real-time updates
 * 
 * This actor (thread-safe class) continuously monitors various device conditions
 * like battery level, thermal state, and network quality. It provides an async stream
 * of health updates that other parts of Kairo can subscribe to.
 * 
 * Key monitoring areas:
 * - Battery level and low power mode
 * - Device thermal state (temperature)
 * - Network connectivity and quality
 * - System resource availability
 */
public actor HealthMonitor {
    
    // MARK: - Properties
    
    /// Current health snapshot
    private var currentSnapshot = HealthSnapshot(
        batteryLevel: 1.0,
        lowPowerMode: false,
        thermalState: .nominal,
        networkReachability: .satisfied,
        networkConstrained: false,
        networkExpensive: false
    )
    
    /// Continuations for async streams - allows multiple subscribers
    private var continuations: [UUID: AsyncStream<HealthSnapshot>.Continuation] = [:]
    
    /// Network path monitor for tracking connectivity
    private var networkMonitor: NWPathMonitor?
    
    /// Timer for periodic health checks
    private var healthCheckTimer: Timer?
    
    /// Whether monitoring is currently active
    private var isMonitoring = false
    
    /// Logger for debugging and monitoring
    private let logger = Logger(category: "HealthMonitor")
    
    // MARK: - Initialization
    
    /**
     * Initialize the health monitor.
     * 
     * This creates a new HealthMonitor instance but doesn't start monitoring yet.
     * Call start() to begin monitoring device conditions.
     */
    public init() {
        logger.info("HealthMonitor initialized")
    }
    
    // MARK: - Public Methods
    
    /**
     * Start monitoring device health conditions.
     * 
     * This method begins continuous monitoring of:
     * - Battery level and low power mode
     * - Device thermal state
     * - Network connectivity and quality
     * 
     * The monitor will emit health updates whenever conditions change significantly.
     * This is an async function, so call it with 'await'.
     */
    public func start() async {
        guard !isMonitoring else {
            logger.warning("HealthMonitor is already running")
            return
        }
        
        logger.info("Starting health monitoring...")
        isMonitoring = true
        
        // Start network monitoring
        await startNetworkMonitoring()
        
        // Start periodic health checks
        await startPeriodicHealthChecks()
        
        // Take initial health snapshot
        await updateHealthSnapshot()
        
        logger.info("Health monitoring started successfully")
    }
    
    /**
     * Stop monitoring and clean up resources.
     * 
     * This stops all monitoring activities and cleans up timers and network monitors.
     * Call this when you no longer need health monitoring.
     */
    public func stop() async {
        guard isMonitoring else {
            logger.warning("HealthMonitor is not running")
            return
        }
        
        logger.info("Stopping health monitoring...")
        isMonitoring = false
        
        // Stop network monitoring
        networkMonitor?.cancel()
        networkMonitor = nil
        
        // Stop periodic health checks
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        
        // Cancel all continuations
        for continuation in continuations.values {
            continuation.finish()
        }
        continuations.removeAll()
        
        logger.info("Health monitoring stopped")
    }
    
    /**
     * Get the current health snapshot.
     * 
     * - Returns: The most recent health snapshot
     * 
     * This provides immediate access to current device health without waiting
     * for the next update cycle.
     */
    public func getCurrentSnapshot() -> HealthSnapshot {
        return currentSnapshot
    }
    
    /**
     * Create an async stream of health updates.
     * 
     * - Returns: An AsyncStream that emits HealthSnapshot objects when conditions change
     * 
     * This is the main way to subscribe to health updates. The stream will emit
     * a new HealthSnapshot whenever device conditions change significantly.
     * 
     * Usage:
     * ```swift
     * for await health in healthMonitor.healthStream() {
     *     // React to health changes
     * }
     * ```
     */
    public func healthStream() -> AsyncStream<HealthSnapshot> {
        return AsyncStream { continuation in
            let id = UUID()
            continuations[id] = continuation
            
            // Send current snapshot immediately
            continuation.yield(currentSnapshot)
            
            // Clean up when the stream ends
            continuation.onTermination = { _ in
                Task { @MainActor in
                    self.continuations.removeValue(forKey: id)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /**
     * Start monitoring network connectivity and quality.
     * 
     * This sets up a network path monitor that tracks:
     * - Whether the device has internet connectivity
     * - Whether the connection is constrained (slow/congested)
     * - Whether the connection is expensive (cellular data)
     */
    private func startNetworkMonitoring() async {
        networkMonitor = NWPathMonitor()
        
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                await self?.handleNetworkPathUpdate(path)
            }
        }
        
        // Start monitoring on a background queue
        let queue = DispatchQueue(label: "com.kairo.network.monitor")
        networkMonitor?.start(queue: queue)
        
        logger.info("Network monitoring started")
    }
    
    /**
     * Handle network path updates from the system.
     * 
     * - Parameter path: The current network path information
     * 
     * This method is called whenever network conditions change. It updates
     * the health snapshot and notifies subscribers if the change is significant.
     */
    private func handleNetworkPathUpdate(_ path: NWPath) async {
        let wasConstrained = currentSnapshot.networkConstrained
        let wasExpensive = currentSnapshot.networkExpensive
        let wasReachable = currentSnapshot.networkReachability
        
        // Update network information
        currentSnapshot.networkReachability = path.status
        currentSnapshot.networkConstrained = path.isConstrained
        currentSnapshot.networkExpensive = path.isExpensive
        
        // Check if this is a significant change worth notifying about
        let significantChange = 
            wasConstrained != currentSnapshot.networkConstrained ||
            wasExpensive != currentSnapshot.networkExpensive ||
            wasReachable != currentSnapshot.networkReachability
        
        if significantChange {
            logger.debug("Network conditions changed: \(path.status), constrained: \(path.isConstrained), expensive: \(path.isExpensive)")
            await notifyHealthUpdate()
        }
    }
    
    /**
     * Start periodic health checks for battery and thermal state.
     * 
     * This sets up a timer that periodically checks:
     * - Battery level and low power mode
     * - Device thermal state
     * - Other system conditions
     * 
     * The timer runs every 5 seconds to balance responsiveness with battery life.
     */
    private func startPeriodicHealthChecks() async {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateHealthSnapshot()
            }
        }
        
        logger.info("Periodic health checks started (every 5 seconds)")
    }
    
    /**
     * Update the health snapshot with current device conditions.
     * 
     * This method gathers all current health information and updates the snapshot.
     * It will notify subscribers if there are significant changes.
     */
    private func updateHealthSnapshot() async {
        let previousSnapshot = currentSnapshot
        
        // Update battery information
        currentSnapshot.batteryLevel = await getBatteryLevel()
        currentSnapshot.lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        
        // Update thermal state
        currentSnapshot.thermalState = ProcessInfo.processInfo.thermalState
        
        // Update timestamp
        currentSnapshot.timestamp = Date()
        
        // Check if this is a significant change
        let significantChange = hasSignificantHealthChange(from: previousSnapshot, to: currentSnapshot)
        
        if significantChange {
            logger.debug("Significant health change detected: battery=\(currentSnapshot.batteryLevel), thermal=\(currentSnapshot.thermalState), lowPower=\(currentSnapshot.lowPowerMode)")
            await notifyHealthUpdate()
        }
    }
    
    /**
     * Get the current battery level from the device.
     * 
     * - Returns: Battery level as a percentage (0.0 to 1.0)
     * 
     * This method accesses the device's battery information through UIDevice.
     * It handles the case where battery monitoring might not be available.
     */
    private func getBatteryLevel() async -> Float {
        // Enable battery monitoring if not already enabled
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        // Get battery level (-1.0 means battery monitoring is not available)
        let batteryLevel = UIDevice.current.batteryLevel
        
        // Return 1.0 (100%) if battery monitoring is not available
        // This is a safe default that won't trigger unnecessary throttling
        return batteryLevel >= 0 ? batteryLevel : 1.0
    }
    
    /**
     * Check if there's been a significant health change worth notifying about.
     * 
     * - Parameters:
     *   - from: Previous health snapshot
     *   - to: Current health snapshot
     * - Returns: True if the change is significant enough to notify subscribers
     * 
     * This prevents spam notifications for minor fluctuations while ensuring
     * important changes are communicated promptly.
     */
    private func hasSignificantHealthChange(from previous: HealthSnapshot, to current: HealthSnapshot) -> Bool {
        // Battery level changed by more than 5%
        let batteryChange = abs(current.batteryLevel - previous.batteryLevel)
        if batteryChange > 0.05 {
            return true
        }
        
        // Thermal state changed
        if current.thermalState != previous.thermalState {
            return true
        }
        
        // Low power mode toggled
        if current.lowPowerMode != previous.lowPowerMode {
            return true
        }
        
        // Network conditions changed
        if current.networkReachability != previous.networkReachability ||
           current.networkConstrained != previous.networkConstrained ||
           current.networkExpensive != previous.networkExpensive {
            return true
        }
        
        // Overall health score changed significantly
        let healthScoreChange = abs(current.overallHealthScore - previous.overallHealthScore)
        if healthScoreChange > 0.1 {
            return true
        }
        
        return false
    }
    
    /**
     * Notify all subscribers about a health update.
     * 
     * This method sends the current health snapshot to all active subscribers
     * of the health stream.
     */
    private func notifyHealthUpdate() async {
        for continuation in continuations.values {
            continuation.yield(currentSnapshot)
        }
    }
}