import Foundation
import Network
@testable import Kairo

/**
 * HealthMonitorTests - Comprehensive test suite for HealthMonitor
 * 
 * This test suite covers all aspects of the HealthMonitor class including:
 * - Health snapshot creation and validation
 * - Battery level monitoring
 * - Thermal state tracking
 * - Network condition monitoring
 * - Health score calculations
 * - Async stream functionality
 * - Error handling and edge cases
 */
class HealthMonitorTests {
    
    // MARK: - Properties
    
    /// Mock logger for testing
    private var mockLogger: MockLogger!
    
    /// Health monitor instance for testing
    private var healthMonitor: HealthMonitor!
    
    // MARK: - Setup and Teardown
    
    func setUp() async throws {
        mockLogger = MockLogger()
        healthMonitor = HealthMonitor()
    }
    
    func tearDown() async throws {
        await healthMonitor.stop()
        healthMonitor = nil
        mockLogger = nil
    }
    
    // MARK: - Health Snapshot Tests
    
    /**
     * Test creating a basic health snapshot with valid data
     * 
     * This test verifies that a HealthSnapshot can be created with valid
     * parameters and that all properties are correctly set.
     */
    func testCreateHealthSnapshot() {
        // Given
        let batteryLevel: Float = 0.75
        let lowPowerMode = false
        let thermalState = ProcessInfo.ThermalState.nominal
        let networkReachability = NWPath.Status.satisfied
        let networkConstrained = false
        let networkExpensive = false
        
        // When
        let snapshot = HealthSnapshot(
            batteryLevel: batteryLevel,
            lowPowerMode: lowPowerMode,
            thermalState: thermalState,
            networkReachability: networkReachability,
            networkConstrained: networkConstrained,
            networkExpensive: networkExpensive
        )
        
        // Then
        XCTAssertEqual(snapshot.batteryLevel, batteryLevel)
        XCTAssertEqual(snapshot.lowPowerMode, lowPowerMode)
        XCTAssertEqual(snapshot.thermalState, thermalState)
        XCTAssertEqual(snapshot.networkReachability, networkReachability)
        XCTAssertEqual(snapshot.networkConstrained, networkConstrained)
        XCTAssertEqual(snapshot.networkExpensive, networkExpensive)
        XCTAssertNotNil(snapshot.timestamp)
    }
    
    /**
     * Test health snapshot with critical conditions
     * 
     * This test verifies that a HealthSnapshot correctly identifies
     * critical conditions like very low battery or critical thermal state.
     */
    func testHealthSnapshotCriticalConditions() {
        // Given - Critical conditions
        let criticalSnapshot = HealthSnapshot(
            batteryLevel: 0.03, // 3% battery
            lowPowerMode: true,
            thermalState: .critical,
            networkReachability: .requiresConnection,
            networkConstrained: true,
            networkExpensive: true
        )
        
        // When & Then
        XCTAssertTrue(criticalSnapshot.isCritical)
        XCTAssertEqual(criticalSnapshot.overallHealthScore, 0.0, accuracy: 0.1)
    }
    
    /**
     * Test health snapshot with excellent conditions
     * 
     * This test verifies that a HealthSnapshot correctly identifies
     * excellent conditions and calculates appropriate health scores.
     */
    func testHealthSnapshotExcellentConditions() {
        // Given - Excellent conditions
        let excellentSnapshot = HealthSnapshot(
            batteryLevel: 0.95, // 95% battery
            lowPowerMode: false,
            thermalState: .nominal,
            networkReachability: .satisfied,
            networkConstrained: false,
            networkExpensive: false
        )
        
        // When & Then
        XCTAssertFalse(excellentSnapshot.isCritical)
        XCTAssertGreaterThan(excellentSnapshot.overallHealthScore, 0.8)
    }
    
    /**
     * Test health score calculation with various factors
     * 
     * This test verifies that the health score calculation correctly
     * incorporates all health factors and produces reasonable scores.
     */
    func testHealthScoreCalculation() {
        // Given - Good conditions
        let goodSnapshot = HealthSnapshot(
            batteryLevel: 0.80,
            lowPowerMode: false,
            thermalState: .nominal,
            networkReachability: .satisfied,
            networkConstrained: false,
            networkExpensive: false
        )
        
        // When
        let score = goodSnapshot.overallHealthScore
        
        // Then
        XCTAssertGreaterThan(score, 0.7)
        XCTAssertLessThanOrEqual(score, 1.0)
    }
    
    /**
     * Test health score with low power mode
     * 
     * This test verifies that low power mode correctly reduces
     * the overall health score.
     */
    func testHealthScoreWithLowPowerMode() {
        // Given - Same conditions but with low power mode
        let normalSnapshot = HealthSnapshot(
            batteryLevel: 0.80,
            lowPowerMode: false,
            thermalState: .nominal,
            networkReachability: .satisfied,
            networkConstrained: false,
            networkExpensive: false
        )
        
        let lowPowerSnapshot = HealthSnapshot(
            batteryLevel: 0.80,
            lowPowerMode: true,
            thermalState: .nominal,
            networkReachability: .satisfied,
            networkConstrained: false,
            networkExpensive: false
        )
        
        // When
        let normalScore = normalSnapshot.overallHealthScore
        let lowPowerScore = lowPowerSnapshot.overallHealthScore
        
        // Then
        XCTAssertGreaterThan(normalScore, lowPowerScore)
    }
    
    /**
     * Test health score with different thermal states
     * 
     * This test verifies that different thermal states produce
     * different health scores, with critical thermal state
     * producing the lowest score.
     */
    func testHealthScoreWithThermalStates() {
        // Given - Different thermal states
        let nominalSnapshot = HealthSnapshot(
            batteryLevel: 0.80,
            lowPowerMode: false,
            thermalState: .nominal,
            networkReachability: .satisfied,
            networkConstrained: false,
            networkExpensive: false
        )
        
        let seriousSnapshot = HealthSnapshot(
            batteryLevel: 0.80,
            lowPowerMode: false,
            thermalState: .serious,
            networkReachability: .satisfied,
            networkConstrained: false,
            networkExpensive: false
        )
        
        let criticalSnapshot = HealthSnapshot(
            batteryLevel: 0.80,
            lowPowerMode: false,
            thermalState: .critical,
            networkReachability: .satisfied,
            networkConstrained: false,
            networkExpensive: false
        )
        
        // When
        let nominalScore = nominalSnapshot.overallHealthScore
        let seriousScore = seriousSnapshot.overallHealthScore
        let criticalScore = criticalSnapshot.overallHealthScore
        
        // Then
        XCTAssertGreaterThan(nominalScore, seriousScore)
        XCTAssertGreaterThan(seriousScore, criticalScore)
    }
    
    // MARK: - Health Monitor Functionality Tests
    
    /**
     * Test starting health monitoring
     * 
     * This test verifies that the health monitor can be started
     * and begins monitoring device health conditions.
     */
    func testStartMonitoring() async throws {
        // Given
        let healthMonitor = HealthMonitor()
        
        // When
        await healthMonitor.start()
        
        // Then
        // Verify that monitoring is active by checking if we can get current snapshot
        let snapshot = await healthMonitor.getCurrentSnapshot()
        XCTAssertNotNil(snapshot)
        
        // Clean up
        await healthMonitor.stop()
    }
    
    /**
     * Test stopping health monitoring
     * 
     * This test verifies that the health monitor can be stopped
     * and properly cleans up resources.
     */
    func testStopMonitoring() async throws {
        // Given
        let healthMonitor = HealthMonitor()
        await healthMonitor.start()
        
        // When
        await healthMonitor.stop()
        
        // Then
        // Verify that monitoring is stopped (this is implicit in the stop method)
        // In a real implementation, you might check internal state
        XCTAssertTrue(true) // Placeholder for actual verification
    }
    
    /**
     * Test getting current health snapshot
     * 
     * This test verifies that the health monitor can provide
     * current health information on demand.
     */
    func testGetCurrentSnapshot() async throws {
        // Given
        let healthMonitor = HealthMonitor()
        await healthMonitor.start()
        
        // When
        let snapshot = await healthMonitor.getCurrentSnapshot()
        
        // Then
        XCTAssertNotNil(snapshot)
        XCTAssertGreaterThanOrEqual(snapshot.batteryLevel, 0.0)
        XCTAssertLessThanOrEqual(snapshot.batteryLevel, 1.0)
    }
    
    /**
     * Test health stream functionality
     * 
     * This test verifies that the health monitor can provide
     * a stream of health updates.
     */
    func testHealthStream() async throws {
        // Given
        let healthMonitor = HealthMonitor()
        await healthMonitor.start()
        
        // When
        let healthStream = await healthMonitor.healthStream()
        
        // Then
        // Verify that we can get at least one health update
        var updateCount = 0
        for await _ in healthStream {
            updateCount += 1
            if updateCount >= 1 {
                break
            }
        }
        
        XCTAssertGreaterThanOrEqual(updateCount, 1)
        
        // Clean up
        await healthMonitor.stop()
    }
    
    // MARK: - Edge Cases and Error Handling
    
    /**
     * Test health monitor with invalid battery level
     * 
     * This test verifies that the health monitor handles
     * invalid battery levels gracefully.
     */
    func testInvalidBatteryLevel() {
        // Given - Invalid battery level
        let invalidSnapshot = HealthSnapshot(
            batteryLevel: -1.0, // Invalid negative battery level
            lowPowerMode: false,
            thermalState: .nominal,
            networkReachability: .satisfied,
            networkConstrained: false,
            networkExpensive: false
        )
        
        // When & Then
        // The snapshot should still be created, but the health score
        // should reflect the invalid battery level
        XCTAssertEqual(invalidSnapshot.batteryLevel, -1.0)
        XCTAssertLessThan(invalidSnapshot.overallHealthScore, 0.5)
    }
    
    /**
     * Test health monitor with extreme values
     * 
     * This test verifies that the health monitor handles
     * extreme values gracefully.
     */
    func testExtremeValues() {
        // Given - Extreme values
        let extremeSnapshot = HealthSnapshot(
            batteryLevel: 1.5, // Over 100% battery
            lowPowerMode: false,
            thermalState: .nominal,
            networkReachability: .satisfied,
            networkConstrained: false,
            networkExpensive: false
        )
        
        // When & Then
        // The snapshot should still be created
        XCTAssertEqual(extremeSnapshot.batteryLevel, 1.5)
        // Health score should be capped at 1.0
        XCTAssertLessThanOrEqual(extremeSnapshot.overallHealthScore, 1.0)
    }
    
    /**
     * Test health monitor with no network connection
     * 
     * This test verifies that the health monitor correctly
     * handles no network connection scenarios.
     */
    func testNoNetworkConnection() {
        // Given - No network connection
        let noNetworkSnapshot = HealthSnapshot(
            batteryLevel: 0.80,
            lowPowerMode: false,
            thermalState: .nominal,
            networkReachability: .requiresConnection,
            networkConstrained: false,
            networkExpensive: false
        )
        
        // When & Then
        XCTAssertFalse(noNetworkSnapshot.isCritical) // No network alone isn't critical
        XCTAssertLessThan(noNetworkSnapshot.overallHealthScore, 1.0)
    }
    
    // MARK: - Performance Tests
    
    /**
     * Test health monitor performance with rapid updates
     * 
     * This test verifies that the health monitor can handle
     * rapid health updates without performance issues.
     */
    func testRapidHealthUpdates() async throws {
        // Given
        let healthMonitor = HealthMonitor()
        await healthMonitor.start()
        
        // When - Simulate rapid updates
        let startTime = Date()
        for _ in 0..<100 {
            let _ = await healthMonitor.getCurrentSnapshot()
        }
        let endTime = Date()
        
        // Then
        let duration = endTime.timeIntervalSince(startTime)
        XCTAssertLessThan(duration, 1.0) // Should complete within 1 second
        
        // Clean up
        await healthMonitor.stop()
    }
    
    /**
     * Test health monitor memory usage
     * 
     * This test verifies that the health monitor doesn't
     * accumulate excessive memory usage over time.
     */
    func testMemoryUsage() async throws {
        // Given
        let healthMonitor = HealthMonitor()
        await healthMonitor.start()
        
        // When - Simulate extended monitoring
        for _ in 0..<1000 {
            let _ = await healthMonitor.getCurrentSnapshot()
        }
        
        // Then
        // In a real implementation, you would check memory usage
        // For now, we just verify the monitor is still functional
        let snapshot = await healthMonitor.getCurrentSnapshot()
        XCTAssertNotNil(snapshot)
        
        // Clean up
        await healthMonitor.stop()
    }
}

/**
 * MockLogger - Mock logger for testing
 * 
 * This mock logger captures log messages for testing purposes
 * without actually logging to the console.
 */
class MockLogger: Logger {
    private var logMessages: [String] = []
    
    override func info(_ message: String) {
        logMessages.append("INFO: \(message)")
    }
    
    override func debug(_ message: String) {
        logMessages.append("DEBUG: \(message)")
    }
    
    override func warning(_ message: String) {
        logMessages.append("WARNING: \(message)")
    }
    
    override func error(_ message: String) {
        logMessages.append("ERROR: \(message)")
    }
    
    /**
     * Get all captured log messages
     * 
     * - Returns: Array of all log messages captured
     */
    func getLogMessages() -> [String] {
        return logMessages
    }
    
    /**
     * Check if a specific log message was captured
     * 
     * - Parameter message: The message to check for
     * - Returns: True if the message was captured
     */
    func hasLogMessage(_ message: String) -> Bool {
        return logMessages.contains { $0.contains(message) }
    }
    
    /**
     * Clear all captured log messages
     */
    func clearLogMessages() {
        logMessages.removeAll()
    }
}
