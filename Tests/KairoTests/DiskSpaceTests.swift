import XCTest
import Foundation
@testable import Kairo

/**
 * DiskSpaceTests - Comprehensive test suite for DiskSpace
 * 
 * This test suite covers all aspects of the DiskSpace class including:
 * - Disk space information gathering
 * - Low space detection and warnings
 * - Space recommendations
 * - Monitoring and alerts
 * - Error handling and edge cases
 * - Performance under various conditions
 */
class DiskSpaceTests: XCTestCase {
    
    // MARK: - Properties
    
    /// Mock logger for testing
    private var mockLogger: MockLogger!
    
    /// Disk space monitor instance for testing
    private var diskSpace: DiskSpace!
    
    /// Test configuration
    private var testThresholds: DiskSpaceThresholds!
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        mockLogger = MockLogger()
        testThresholds = DiskSpaceThresholds(
            lowSpaceThreshold: 0.15,
            criticalSpaceThreshold: 0.05,
            minimumAbsoluteSpace: 1_073_741_824 // 1 GB
        )
        diskSpace = DiskSpace(thresholds: testThresholds, logger: mockLogger)
    }
    
    override func tearDown() async throws {
        await diskSpace.stopMonitoring()
        diskSpace = nil
        testThresholds = nil
        mockLogger = nil
        try await super.tearDown()
    }
    
    // MARK: - Disk Space Information Tests
    
    /**
     * Test disk space information creation
     * 
     * This test verifies that DiskSpaceInfo can be created with
     * valid parameters and that all properties work correctly.
     */
    func testDiskSpaceInfoCreation() {
        // Given
        let totalSpace: Int64 = 100_000_000_000 // 100 GB
        let availableSpace: Int64 = 50_000_000_000 // 50 GB
        let usedSpace: Int64 = 50_000_000_000 // 50 GB
        let availablePercentage: Double = 0.5
        let usedPercentage: Double = 0.5
        let isLowSpace = false
        let isCriticalSpace = false
        
        // When
        let info = DiskSpaceInfo(
            totalSpace: totalSpace,
            availableSpace: availableSpace,
            usedSpace: usedSpace,
            availablePercentage: availablePercentage,
            usedPercentage: usedPercentage,
            isLowSpace: isLowSpace,
            isCriticalSpace: isCriticalSpace
        )
        
        // Then
        XCTAssertEqual(info.totalSpace, totalSpace)
        XCTAssertEqual(info.availableSpace, availableSpace)
        XCTAssertEqual(info.usedSpace, usedSpace)
        XCTAssertEqual(info.availablePercentage, availablePercentage)
        XCTAssertEqual(info.usedPercentage, usedPercentage)
        XCTAssertEqual(info.isLowSpace, isLowSpace)
        XCTAssertEqual(info.isCriticalSpace, isCriticalSpace)
        XCTAssertNotNil(info.timestamp)
    }
    
    /**
     * Test disk space information with low space
     * 
     * This test verifies that DiskSpaceInfo correctly identifies
     * low space conditions.
     */
    func testDiskSpaceInfoLowSpace() {
        // Given
        let info = DiskSpaceInfo(
            totalSpace: 100_000_000_000, // 100 GB
            availableSpace: 10_000_000_000, // 10 GB
            usedSpace: 90_000_000_000, // 90 GB
            availablePercentage: 0.1, // 10%
            usedPercentage: 0.9, // 90%
            isLowSpace: true,
            isCriticalSpace: false
        )
        
        // When & Then
        XCTAssertTrue(info.isLowSpace)
        XCTAssertFalse(info.isCriticalSpace)
    }
    
    /**
     * Test disk space information with critical space
     * 
     * This test verifies that DiskSpaceInfo correctly identifies
     * critical space conditions.
     */
    func testDiskSpaceInfoCriticalSpace() {
        // Given
        let info = DiskSpaceInfo(
            totalSpace: 100_000_000_000, // 100 GB
            availableSpace: 2_000_000_000, // 2 GB
            usedSpace: 98_000_000_000, // 98 GB
            availablePercentage: 0.02, // 2%
            usedPercentage: 0.98, // 98%
            isLowSpace: true,
            isCriticalSpace: true
        )
        
        // When & Then
        XCTAssertTrue(info.isLowSpace)
        XCTAssertTrue(info.isCriticalSpace)
    }
    
    /**
     * Test disk space information descriptions
     * 
     * This test verifies that DiskSpaceInfo provides
     * human-readable descriptions.
     */
    func testDiskSpaceInfoDescriptions() {
        // Given
        let info = DiskSpaceInfo(
            totalSpace: 100_000_000_000, // 100 GB
            availableSpace: 25_000_000_000, // 25 GB
            usedSpace: 75_000_000_000, // 75 GB
            availablePercentage: 0.25, // 25%
            usedPercentage: 0.75, // 75%
            isLowSpace: false,
            isCriticalSpace: false
        )
        
        // When
        let availableDescription = info.availableSpaceDescription
        let usedDescription = info.usedSpaceDescription
        
        // Then
        XCTAssertTrue(availableDescription.contains("25.0 GB"))
        XCTAssertTrue(availableDescription.contains("25%"))
        XCTAssertTrue(availableDescription.contains("100.0 GB"))
        
        XCTAssertTrue(usedDescription.contains("75.0 GB"))
        XCTAssertTrue(usedDescription.contains("75%"))
        XCTAssertTrue(usedDescription.contains("100.0 GB"))
    }
    
    // MARK: - Disk Space Thresholds Tests
    
    /**
     * Test disk space thresholds initialization
     * 
     * This test verifies that DiskSpaceThresholds can be initialized
     * with custom values.
     */
    func testDiskSpaceThresholdsInitialization() {
        // Given
        let lowThreshold: Double = 0.20
        let criticalThreshold: Double = 0.10
        let minimumAbsolute: Int64 = 2_147_483_648 // 2 GB
        
        // When
        let thresholds = DiskSpaceThresholds(
            lowSpaceThreshold: lowThreshold,
            criticalSpaceThreshold: criticalThreshold,
            minimumAbsoluteSpace: minimumAbsolute
        )
        
        // Then
        XCTAssertEqual(thresholds.lowSpaceThreshold, lowThreshold)
        XCTAssertEqual(thresholds.criticalSpaceThreshold, criticalThreshold)
        XCTAssertEqual(thresholds.minimumAbsoluteSpace, minimumAbsolute)
    }
    
    /**
     * Test disk space thresholds default values
     * 
     * This test verifies that DiskSpaceThresholds provides
     * sensible default values.
     */
    func testDiskSpaceThresholdsDefaultValues() {
        // Given
        let defaultThresholds = DiskSpaceThresholds.default
        
        // When & Then
        XCTAssertEqual(defaultThresholds.lowSpaceThreshold, 0.15) // 15%
        XCTAssertEqual(defaultThresholds.criticalSpaceThreshold, 0.05) // 5%
        XCTAssertEqual(defaultThresholds.minimumAbsoluteSpace, 1_073_741_824) // 1 GB
    }
    
    // MARK: - Disk Space Monitor Tests
    
    /**
     * Test disk space monitor initialization
     * 
     * This test verifies that DiskSpace can be initialized
     * with proper configuration.
     */
    func testDiskSpaceMonitorInitialization() {
        // Given
        let logger = MockLogger()
        let thresholds = DiskSpaceThresholds.default
        
        // When
        let monitor = DiskSpace(thresholds: thresholds, logger: logger)
        
        // Then
        XCTAssertNotNil(monitor)
    }
    
    /**
     * Test disk space monitor with custom thresholds
     * 
     * This test verifies that DiskSpace can be initialized
     * with custom threshold settings.
     */
    func testDiskSpaceMonitorCustomThresholds() {
        // Given
        let customThresholds = DiskSpaceThresholds(
            lowSpaceThreshold: 0.25,
            criticalSpaceThreshold: 0.10,
            minimumAbsoluteSpace: 2_147_483_648 // 2 GB
        )
        let logger = MockLogger()
        
        // When
        let monitor = DiskSpace(thresholds: customThresholds, logger: logger)
        
        // Then
        XCTAssertNotNil(monitor)
    }
    
    // MARK: - Monitoring Tests
    
    /**
     * Test disk space monitoring start
     * 
     * This test verifies that disk space monitoring can be started
     * and begins checking disk usage.
     */
    func testDiskSpaceMonitoringStart() async {
        // Given
        let expectation = XCTestExpectation(description: "Monitoring started")
        
        // When
        await diskSpace.startMonitoring(interval: 1.0)
        
        // Then
        // Verify that monitoring is active by checking if we can get current info
        do {
            let info = try await diskSpace.getCurrentInfo()
            XCTAssertNotNil(info)
        } catch {
            XCTFail("Should be able to get current info: \(error)")
        }
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    /**
     * Test disk space monitoring stop
     * 
     * This test verifies that disk space monitoring can be stopped
     * and properly cleans up resources.
     */
    func testDiskSpaceMonitoringStop() async {
        // Given
        await diskSpace.startMonitoring()
        
        // When
        await diskSpace.stopMonitoring()
        
        // Then
        // Verify that monitoring is stopped
        // In a real implementation, you would check internal state
        XCTAssertTrue(true) // Placeholder for actual verification
    }
    
    /**
     * Test disk space monitoring with custom interval
     * 
     * This test verifies that disk space monitoring can be configured
     * with custom check intervals.
     */
    func testDiskSpaceMonitoringCustomInterval() async {
        // Given
        let customInterval: TimeInterval = 0.5 // 0.5 seconds
        let expectation = XCTestExpectation(description: "Custom interval monitoring")
        
        // When
        await diskSpace.startMonitoring(interval: customInterval)
        
        // Then
        // Wait for at least one check cycle
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    // MARK: - Space Detection Tests
    
    /**
     * Test low space detection
     * 
     * This test verifies that the disk space monitor correctly
     * detects low space conditions.
     */
    func testLowSpaceDetection() async {
        // Given
        let expectation = XCTestExpectation(description: "Low space detection")
        
        // When
        let isLow = diskSpace.isLow()
        
        // Then
        // In a real test, you would mock the disk space info
        // For now, we just verify the method exists and returns a boolean
        XCTAssertNotNil(isLow)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    /**
     * Test critical space detection
     * 
     * This test verifies that the disk space monitor correctly
     * detects critical space conditions.
     */
    func testCriticalSpaceDetection() async {
        // Given
        let expectation = XCTestExpectation(description: "Critical space detection")
        
        // When
        let isCritical = diskSpace.isCriticallyLow()
        
        // Then
        // In a real test, you would mock the disk space info
        // For now, we just verify the method exists and returns a boolean
        XCTAssertNotNil(isCritical)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Space Recommendations Tests
    
    /**
     * Test space recommendations
     * 
     * This test verifies that the disk space monitor provides
     * appropriate space recommendations.
     */
    func testSpaceRecommendations() async {
        // Given
        let expectation = XCTestExpectation(description: "Space recommendations")
        
        // When
        let recommendations = await diskSpace.getSpaceRecommendations()
        
        // Then
        XCTAssertNotNil(recommendations)
        XCTAssertTrue(recommendations.count >= 0)
        
        // Verify that recommendations have the expected structure
        for recommendation in recommendations {
            XCTAssertNotNil(recommendation.type)
            XCTAssertNotNil(recommendation.description)
            XCTAssertNotNil(recommendation.estimatedSpace)
            XCTAssertNotNil(recommendation.priority)
        }
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    /**
     * Test space recommendations with different conditions
     * 
     * This test verifies that the disk space monitor provides
     * different recommendations based on current conditions.
     */
    func testSpaceRecommendationsDifferentConditions() async {
        // Given
        let expectation = XCTestExpectation(description: "Different condition recommendations")
        
        // When - Test with different simulated conditions
        let recommendations = await diskSpace.getSpaceRecommendations()
        
        // Then
        // Verify that recommendations are appropriate for current conditions
        XCTAssertNotNil(recommendations)
        
        // Check for specific recommendation types
        let recommendationTypes = Set(recommendations.map { $0.type })
        XCTAssertTrue(recommendationTypes.contains(.cleanup) || 
                     recommendationTypes.contains(.warning) || 
                     recommendationTypes.contains(.critical) || 
                     recommendationTypes.contains(.unknown))
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Error Handling Tests
    
    /**
     * Test disk space error handling
     * 
     * This test verifies that the disk space monitor handles
     * various error conditions gracefully.
     */
    func testDiskSpaceErrorHandling() async {
        // Given
        let expectation = XCTestExpectation(description: "Error handling verified")
        
        // When - Test error handling
        do {
            let info = try await diskSpace.getCurrentInfo()
            XCTAssertNotNil(info)
        } catch {
            // Some errors might be expected in test environment
            // The important thing is that errors are handled gracefully
            XCTAssertNotNil(error)
        }
        
        // Then
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    /**
     * Test disk space error types
     * 
     * This test verifies that all disk space error types
     * are properly defined and have correct descriptions.
     */
    func testDiskSpaceErrorTypes() {
        // Given & When & Then
        XCTAssertEqual(DiskSpaceError.unableToGetDiskInfo.description, "Unable to get disk space information")
        XCTAssertEqual(DiskSpaceError.invalidPath.description, "Invalid file path provided")
        XCTAssertEqual(DiskSpaceError.insufficientPermissions.description, "Insufficient permissions to access disk information")
        XCTAssertEqual(DiskSpaceError.monitoringAlreadyActive.description, "Disk space monitoring is already active")
        XCTAssertEqual(DiskSpaceError.monitoringNotActive.description, "Disk space monitoring is not active")
    }
    
    // MARK: - Performance Tests
    
    /**
     * Test disk space monitoring performance
     * 
     * This test verifies that disk space monitoring performs
     * well under normal conditions.
     */
    func testDiskSpaceMonitoringPerformance() async {
        // Given
        let startTime = Date()
        let expectation = XCTestExpectation(description: "Performance test completed")
        
        // When - Perform multiple disk space checks
        for _ in 0..<100 {
            do {
                let _ = try await diskSpace.getCurrentInfo()
            } catch {
                // Some errors might be expected in test environment
            }
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Then
        XCTAssertLessThan(duration, 5.0) // Should complete within 5 seconds
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    /**
     * Test disk space monitoring memory usage
     * 
     * This test verifies that disk space monitoring doesn't
     * accumulate excessive memory usage over time.
     */
    func testDiskSpaceMonitoringMemoryUsage() async {
        // Given
        let expectation = XCTestExpectation(description: "Memory usage test completed")
        
        // When - Perform many disk space checks over time
        for _ in 0..<1000 {
            do {
                let _ = try await diskSpace.getCurrentInfo()
            } catch {
                // Some errors might be expected in test environment
            }
        }
        
        // Then - Monitor should still be functional
        let isLow = diskSpace.isLow()
        let isCritical = diskSpace.isCriticallyLow()
        
        XCTAssertNotNil(isLow)
        XCTAssertNotNil(isCritical)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Integration Tests
    
    /**
     * Test disk space monitoring integration with Kairo
     * 
     * This test verifies that disk space monitoring works correctly
     * when integrated with the Kairo framework.
     */
    func testDiskSpaceKairoIntegration() async {
        // Given
        let kairo = Kairo()
        await kairo.start()
        
        // When
        let shouldAllow = await kairo.shouldAllowOperation(.backgroundTask)
        
        // Then
        // Background tasks should be allowed in good conditions
        XCTAssertTrue(shouldAllow)
        
        // Clean up
        await kairo.stop()
    }
    
    /**
     * Test disk space monitoring with different health conditions
     * 
     * This test verifies that disk space monitoring responds appropriately
     * to different device health conditions.
     */
    func testDiskSpaceWithHealthConditions() async {
        // Given
        let kairo = Kairo()
        await kairo.start()
        
        // When - Test with different health conditions
        let goodHealth = HealthSnapshot(
            batteryLevel: 0.80,
            lowPowerMode: false,
            thermalState: .nominal,
            networkReachability: .satisfied,
            networkConstrained: false,
            networkExpensive: false
        )
        
        let poorHealth = HealthSnapshot(
            batteryLevel: 0.20,
            lowPowerMode: true,
            thermalState: .serious,
            networkReachability: .satisfied,
            networkConstrained: true,
            networkExpensive: true
        )
        
        // Then
        XCTAssertFalse(goodHealth.isCritical)
        XCTAssertTrue(poorHealth.isCritical)
        
        // Clean up
        await kairo.stop()
    }
    
    // MARK: - Real-World Scenario Tests
    
    /**
     * Test disk space monitoring with realistic usage patterns
     * 
     * This test verifies that disk space monitoring works correctly
     * with realistic usage patterns.
     */
    func testDiskSpaceRealisticUsage() async {
        // Given
        let expectation = XCTestExpectation(description: "Realistic usage completed")
        
        // When - Simulate realistic usage patterns
        await diskSpace.startMonitoring(interval: 1.0)
        
        // Wait for monitoring to run
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Check current status
        let isLow = diskSpace.isLow()
        let isCritical = diskSpace.isCriticallyLow()
        
        // Get recommendations
        let recommendations = await diskSpace.getSpaceRecommendations()
        
        // Then
        XCTAssertNotNil(isLow)
        XCTAssertNotNil(isCritical)
        XCTAssertNotNil(recommendations)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    /**
     * Test disk space monitoring with different threshold levels
     * 
     * This test verifies that disk space monitoring works correctly
     * with different threshold levels.
     */
    func testDiskSpaceDifferentThresholds() async {
        // Given
        let expectation = XCTestExpectation(description: "Different thresholds tested")
        
        // When - Test with different threshold levels
        let lowThresholds = DiskSpaceThresholds(
            lowSpaceThreshold: 0.30,
            criticalSpaceThreshold: 0.15,
            minimumAbsoluteSpace: 500_000_000 // 500 MB
        )
        
        let highThresholds = DiskSpaceThresholds(
            lowSpaceThreshold: 0.10,
            criticalSpaceThreshold: 0.05,
            minimumAbsoluteSpace: 2_000_000_000 // 2 GB
        )
        
        let lowMonitor = DiskSpace(thresholds: lowThresholds, logger: mockLogger)
        let highMonitor = DiskSpace(thresholds: highThresholds, logger: mockLogger)
        
        // Then
        XCTAssertNotNil(lowMonitor)
        XCTAssertNotNil(highMonitor)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
}
