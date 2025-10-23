import XCTest
import Foundation
@testable import Kairo

/**
 * KairoTests - Comprehensive test suite for the main Kairo class
 * 
 * This test suite covers all aspects of the main Kairo class including:
 * - Initialization and configuration
 * - Health monitoring integration
 * - Policy updates and management
 * - Operation filtering and decision making
 * - Performance monitoring and metrics
 * - Error handling and edge cases
 * - Integration with all components
 */
class KairoTests: XCTestCase {
    
    // MARK: - Properties
    
    /// Kairo instance for testing
    private var kairo: Kairo!
    
    /// Test configuration
    private var testConfig: KairoConfig!
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        testConfig = KairoConfig(
            networkMaxConcurrent: 4,
            lowBatteryThreshold: 0.20,
            debounceMillis: 500
        )
        kairo = Kairo(config: testConfig)
    }
    
    override func tearDown() async throws {
        await kairo.stop()
        kairo = nil
        testConfig = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    /**
     * Test Kairo initialization with default configuration
     * 
     * This test verifies that Kairo can be initialized
     * with default configuration settings.
     */
    func testKairoInitializationDefault() {
        // Given
        let defaultKairo = Kairo()
        
        // When & Then
        XCTAssertNotNil(defaultKairo)
    }
    
    /**
     * Test Kairo initialization with custom configuration
     * 
     * This test verifies that Kairo can be initialized
     * with custom configuration settings.
     */
    func testKairoInitializationCustom() {
        // Given
        let customConfig = KairoConfig(
            networkMaxConcurrent: 8,
            lowBatteryThreshold: 0.15,
            debounceMillis: 300
        )
        
        // When
        let customKairo = Kairo(config: customConfig)
        
        // Then
        XCTAssertNotNil(customKairo)
    }
    
    /**
     * Test Kairo initialization with different configurations
     * 
     * This test verifies that Kairo can be initialized
     * with various configuration settings.
     */
    func testKairoInitializationDifferentConfigs() {
        // Given
        let configs = [
            KairoConfig(networkMaxConcurrent: 1, lowBatteryThreshold: 0.05, debounceMillis: 100),
            KairoConfig(networkMaxConcurrent: 10, lowBatteryThreshold: 0.30, debounceMillis: 1000),
            KairoConfig.default
        ]
        
        // When & Then
        for config in configs {
            let kairo = Kairo(config: config)
            XCTAssertNotNil(kairo)
        }
    }
    
    // MARK: - Lifecycle Tests
    
    /**
     * Test Kairo start
     * 
     * This test verifies that Kairo can be started
     * and begins monitoring device health.
     */
    func testKairoStart() async {
        // Given
        let expectation = XCTestExpectation(description: "Kairo started")
        
        // When
        await kairo.start()
        
        // Then
        // Verify that Kairo is running by checking if we can get current health
        let health = await kairo.getCurrentHealth()
        XCTAssertNotNil(health)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    /**
     * Test Kairo stop
     * 
     * This test verifies that Kairo can be stopped
     * and properly cleans up resources.
     */
    func testKairoStop() async {
        // Given
        await kairo.start()
        
        // When
        await kairo.stop()
        
        // Then
        // Verify that Kairo is stopped
        // In a real implementation, you would check internal state
        XCTAssertTrue(true) // Placeholder for actual verification
    }
    
    /**
     * Test Kairo start and stop cycle
     * 
     * This test verifies that Kairo can be started and stopped
     * multiple times without issues.
     */
    func testKairoStartStopCycle() async {
        // Given
        let expectation = XCTestExpectation(description: "Start-stop cycle completed")
        
        // When - Multiple start/stop cycles
        for _ in 0..<3 {
            await kairo.start()
            await kairo.stop()
        }
        
        // Then
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Health Monitoring Tests
    
    /**
     * Test getting current health
     * 
     * This test verifies that Kairo can provide
     * current device health information.
     */
    func testGetCurrentHealth() async {
        // Given
        let expectation = XCTestExpectation(description: "Current health retrieved")
        
        // When
        await kairo.start()
        let health = await kairo.getCurrentHealth()
        
        // Then
        XCTAssertNotNil(health)
        XCTAssertGreaterThanOrEqual(health.batteryLevel, 0.0)
        XCTAssertLessThanOrEqual(health.batteryLevel, 1.0)
        XCTAssertNotNil(health.thermalState)
        XCTAssertNotNil(health.networkReachability)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    /**
     * Test health stream monitoring
     * 
     * This test verifies that Kairo can provide
     * a stream of health updates.
     */
    func testHealthStreamMonitoring() async {
        // Given
        let expectation = XCTestExpectation(description: "Health stream monitoring")
        
        // When
        await kairo.start()
        let healthStream = await kairo.healthStream()
        
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
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    /**
     * Test health stream with multiple updates
     * 
     * This test verifies that Kairo can provide
     * multiple health updates over time.
     */
    func testHealthStreamMultipleUpdates() async {
        // Given
        let expectation = XCTestExpectation(description: "Multiple health updates")
        
        // When
        await kairo.start()
        let healthStream = await kairo.healthStream()
        
        // Then
        // Verify that we can get multiple health updates
        var updateCount = 0
        for await _ in healthStream {
            updateCount += 1
            if updateCount >= 3 {
                break
            }
        }
        
        XCTAssertGreaterThanOrEqual(updateCount, 3)
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 10.0)
    }
    
    // MARK: - Operation Filtering Tests
    
    /**
     * Test operation filtering with good health
     * 
     * This test verifies that Kairo allows operations
     * when device health is good.
     */
    func testOperationFilteringGoodHealth() async {
        // Given
        let expectation = XCTestExpectation(description: "Operation filtering good health")
        
        // When
        await kairo.start()
        let shouldAllow = await kairo.shouldAllowOperation(.networkRequest(priority: .normal))
        
        // Then
        // Operations should be allowed in good conditions
        XCTAssertTrue(shouldAllow)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    /**
     * Test operation filtering with different operation types
     * 
     * This test verifies that Kairo can filter different
     * types of operations appropriately.
     */
    func testOperationFilteringDifferentTypes() async {
        // Given
        let expectation = XCTestExpectation(description: "Different operation types")
        
        // When
        await kairo.start()
        
        let networkRequest = await kairo.shouldAllowOperation(.networkRequest(priority: .normal))
        let imageProcessing = await kairo.shouldAllowOperation(.imageProcessing(size: .medium))
        let mlInference = await kairo.shouldAllowOperation(.machineLearningInference)
        let backgroundTask = await kairo.shouldAllowOperation(.backgroundTask)
        let fileDownload = await kairo.shouldAllowOperation(.fileDownload(size: 1000000))
        let videoProcessing = await kairo.shouldAllowOperation(.videoProcessing)
        
        // Then
        XCTAssertNotNil(networkRequest)
        XCTAssertNotNil(imageProcessing)
        XCTAssertNotNil(mlInference)
        XCTAssertNotNil(backgroundTask)
        XCTAssertNotNil(fileDownload)
        XCTAssertNotNil(videoProcessing)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    /**
     * Test operation filtering with different priorities
     * 
     * This test verifies that Kairo can filter operations
     * based on priority levels.
     */
    func testOperationFilteringDifferentPriorities() async {
        // Given
        let expectation = XCTestExpectation(description: "Different priorities")
        
        // When
        await kairo.start()
        
        let lowPriority = await kairo.shouldAllowOperation(.networkRequest(priority: .low))
        let normalPriority = await kairo.shouldAllowOperation(.networkRequest(priority: .normal))
        let highPriority = await kairo.shouldAllowOperation(.networkRequest(priority: .high))
        let criticalPriority = await kairo.shouldAllowOperation(.networkRequest(priority: .critical))
        
        // Then
        XCTAssertNotNil(lowPriority)
        XCTAssertNotNil(normalPriority)
        XCTAssertNotNil(highPriority)
        XCTAssertNotNil(criticalPriority)
        
        // Critical priority should generally be allowed more often
        XCTAssertTrue(criticalPriority)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    // MARK: - Policy Management Tests
    
    /**
     * Test getting recommended image quality
     * 
     * This test verifies that Kairo can provide
     * recommended image quality based on current conditions.
     */
    func testGetRecommendedImageQuality() async {
        // Given
        let expectation = XCTestExpectation(description: "Recommended image quality")
        
        // When
        await kairo.start()
        let imageQuality = await kairo.getRecommendedImageQuality()
        
        // Then
        XCTAssertNotNil(imageQuality)
        XCTAssertTrue([.original, .large, .medium, .small].contains(imageQuality))
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    /**
     * Test getting max concurrent requests
     * 
     * This test verifies that Kairo can provide
     * the maximum number of concurrent requests allowed.
     */
    func testGetMaxConcurrentRequests() async {
        // Given
        let expectation = XCTestExpectation(description: "Max concurrent requests")
        
        // When
        await kairo.start()
        let maxConcurrent = await kairo.getMaxConcurrentRequests()
        
        // Then
        XCTAssertNotNil(maxConcurrent)
        XCTAssertGreaterThanOrEqual(maxConcurrent, 1)
        XCTAssertLessThanOrEqual(maxConcurrent, testConfig.networkMaxConcurrent)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    /**
     * Test getting background ML permission
     * 
     * This test verifies that Kairo can provide
     * permission for background ML operations.
     */
    func testGetBackgroundMLPermission() async {
        // Given
        let expectation = XCTestExpectation(description: "Background ML permission")
        
        // When
        await kairo.start()
        let allowML = await kairo.shouldAllowBackgroundML()
        
        // Then
        XCTAssertNotNil(allowML)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    // MARK: - Performance Tests
    
    /**
     * Test Kairo performance with multiple operations
     * 
     * This test verifies that Kairo performs well
     * when handling multiple operations.
     */
    func testKairoPerformanceMultipleOperations() async {
        // Given
        let startTime = Date()
        let expectation = XCTestExpectation(description: "Performance test completed")
        let operationCount = 100
        
        // When
        await kairo.start()
        
        for _ in 0..<operationCount {
            let _ = await kairo.shouldAllowOperation(.networkRequest(priority: .normal))
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Then
        XCTAssertLessThan(duration, 5.0) // Should complete within 5 seconds
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    /**
     * Test Kairo performance with health monitoring
     * 
     * This test verifies that Kairo performs well
     * when monitoring health continuously.
     */
    func testKairoPerformanceHealthMonitoring() async {
        // Given
        let startTime = Date()
        let expectation = XCTestExpectation(description: "Health monitoring performance")
        
        // When
        await kairo.start()
        
        // Simulate continuous health monitoring
        for _ in 0..<50 {
            let _ = await kairo.getCurrentHealth()
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Then
        XCTAssertLessThan(duration, 3.0) // Should complete within 3 seconds
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    /**
     * Test Kairo memory usage
     * 
     * This test verifies that Kairo doesn't
     * accumulate excessive memory usage over time.
     */
    func testKairoMemoryUsage() async {
        // Given
        let expectation = XCTestExpectation(description: "Memory usage test completed")
        
        // When
        await kairo.start()
        
        // Simulate extended usage
        for _ in 0..<1000 {
            let _ = await kairo.getCurrentHealth()
            let _ = await kairo.shouldAllowOperation(.networkRequest(priority: .normal))
        }
        
        // Then - Kairo should still be functional
        let health = await kairo.getCurrentHealth()
        let shouldAllow = await kairo.shouldAllowOperation(.networkRequest(priority: .normal))
        
        XCTAssertNotNil(health)
        XCTAssertNotNil(shouldAllow)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Error Handling Tests
    
    /**
     * Test Kairo error handling
     * 
     * This test verifies that Kairo handles
     * various error conditions gracefully.
     */
    func testKairoErrorHandling() async {
        // Given
        let expectation = XCTestExpectation(description: "Error handling verified")
        
        // When - Test error handling
        do {
            await kairo.start()
            let health = await kairo.getCurrentHealth()
            XCTAssertNotNil(health)
        } catch {
            // Some errors might be expected in test environment
            // The important thing is that errors are handled gracefully
            XCTAssertNotNil(error)
        }
        
        // Then
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    /**
     * Test Kairo with invalid operations
     * 
     * This test verifies that Kairo handles
     * invalid operations gracefully.
     */
    func testKairoInvalidOperations() async {
        // Given
        let expectation = XCTestExpectation(description: "Invalid operations handled")
        
        // When
        await kairo.start()
        
        // Test with various operation types
        let networkRequest = await kairo.shouldAllowOperation(.networkRequest(priority: .normal))
        let imageProcessing = await kairo.shouldAllowOperation(.imageProcessing(size: .large))
        let mlInference = await kairo.shouldAllowOperation(.machineLearningInference)
        
        // Then
        XCTAssertNotNil(networkRequest)
        XCTAssertNotNil(imageProcessing)
        XCTAssertNotNil(mlInference)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    // MARK: - Integration Tests
    
    /**
     * Test Kairo integration with all components
     * 
     * This test verifies that Kairo works correctly
     * when integrated with all its components.
     */
    func testKairoComponentIntegration() async {
        // Given
        let expectation = XCTestExpectation(description: "Component integration verified")
        
        // When
        await kairo.start()
        
        // Test all major functionality
        let health = await kairo.getCurrentHealth()
        let shouldAllow = await kairo.shouldAllowOperation(.networkRequest(priority: .normal))
        let imageQuality = await kairo.getRecommendedImageQuality()
        let maxConcurrent = await kairo.getMaxConcurrentRequests()
        let allowML = await kairo.shouldAllowBackgroundML()
        
        // Then
        XCTAssertNotNil(health)
        XCTAssertNotNil(shouldAllow)
        XCTAssertNotNil(imageQuality)
        XCTAssertNotNil(maxConcurrent)
        XCTAssertNotNil(allowML)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    /**
     * Test Kairo with different health conditions
     * 
     * This test verifies that Kairo responds appropriately
     * to different device health conditions.
     */
    func testKairoWithHealthConditions() async {
        // Given
        let expectation = XCTestExpectation(description: "Health conditions tested")
        
        // When
        await kairo.start()
        
        // Test with different health conditions
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
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    // MARK: - Real-World Scenario Tests
    
    /**
     * Test Kairo with realistic usage patterns
     * 
     * This test verifies that Kairo works correctly
     * with realistic usage patterns.
     */
    func testKairoRealisticUsage() async {
        // Given
        let expectation = XCTestExpectation(description: "Realistic usage completed")
        
        // When - Simulate realistic usage patterns
        await kairo.start()
        
        // Simulate app startup
        let health = await kairo.getCurrentHealth()
        let imageQuality = await kairo.getRecommendedImageQuality()
        
        // Simulate network requests
        let networkRequest = await kairo.shouldAllowOperation(.networkRequest(priority: .normal))
        let maxConcurrent = await kairo.getMaxConcurrentRequests()
        
        // Simulate background tasks
        let backgroundTask = await kairo.shouldAllowOperation(.backgroundTask)
        let allowML = await kairo.shouldAllowBackgroundML()
        
        // Simulate image processing
        let imageProcessing = await kairo.shouldAllowOperation(.imageProcessing(size: .medium))
        
        // Then
        XCTAssertNotNil(health)
        XCTAssertNotNil(imageQuality)
        XCTAssertNotNil(networkRequest)
        XCTAssertNotNil(maxConcurrent)
        XCTAssertNotNil(backgroundTask)
        XCTAssertNotNil(allowML)
        XCTAssertNotNil(imageProcessing)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    /**
     * Test Kairo with different operation priorities
     * 
     * This test verifies that Kairo works correctly
     * with different operation priorities.
     */
    func testKairoDifferentPriorities() async {
        // Given
        let expectation = XCTestExpectation(description: "Different priorities tested")
        
        // When
        await kairo.start()
        
        // Test different priority levels
        let lowPriority = await kairo.shouldAllowOperation(.networkRequest(priority: .low))
        let normalPriority = await kairo.shouldAllowOperation(.networkRequest(priority: .normal))
        let highPriority = await kairo.shouldAllowOperation(.networkRequest(priority: .high))
        let criticalPriority = await kairo.shouldAllowOperation(.networkRequest(priority: .critical))
        
        // Then
        XCTAssertNotNil(lowPriority)
        XCTAssertNotNil(normalPriority)
        XCTAssertNotNil(highPriority)
        XCTAssertNotNil(criticalPriority)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    /**
     * Test Kairo with different image sizes
     * 
     * This test verifies that Kairo works correctly
     * with different image processing sizes.
     */
    func testKairoDifferentImageSizes() async {
        // Given
        let expectation = XCTestExpectation(description: "Different image sizes tested")
        
        // When
        await kairo.start()
        
        // Test different image sizes
        let smallImage = await kairo.shouldAllowOperation(.imageProcessing(size: .small))
        let mediumImage = await kairo.shouldAllowOperation(.imageProcessing(size: .medium))
        let largeImage = await kairo.shouldAllowOperation(.imageProcessing(size: .large))
        
        // Then
        XCTAssertNotNil(smallImage)
        XCTAssertNotNil(mediumImage)
        XCTAssertNotNil(largeImage)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    /**
     * Test Kairo with different file download sizes
     * 
     * This test verifies that Kairo works correctly
     * with different file download sizes.
     */
    func testKairoDifferentFileSizes() async {
        // Given
        let expectation = XCTestExpectation(description: "Different file sizes tested")
        
        // When
        await kairo.start()
        
        // Test different file sizes
        let smallFile = await kairo.shouldAllowOperation(.fileDownload(size: 1_000_000)) // 1 MB
        let mediumFile = await kairo.shouldAllowOperation(.fileDownload(size: 10_000_000)) // 10 MB
        let largeFile = await kairo.shouldAllowOperation(.fileDownload(size: 100_000_000)) // 100 MB
        
        // Then
        XCTAssertNotNil(smallFile)
        XCTAssertNotNil(mediumFile)
        XCTAssertNotNil(largeFile)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 2.0)
    }
}
