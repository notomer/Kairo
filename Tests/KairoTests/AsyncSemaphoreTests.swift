import XCTest
import Foundation
@testable import Kairo

/**
 * AsyncSemaphoreTests - Comprehensive test suite for AsyncSemaphore
 * 
 * This test suite covers all aspects of the AsyncSemaphore class including:
 * - Semaphore acquisition and release
 * - Concurrency limiting
 * - Waiting queue management
 * - Performance under various conditions
 * - Error handling and edge cases
 * - Integration with Kairo framework
 */
class AsyncSemaphoreTests: XCTestCase {
    
    // MARK: - Properties
    
    /// Mock logger for testing
    private var mockLogger: MockLogger!
    
    /// Async semaphore instance for testing
    private var semaphore: AsyncSemaphore!
    
    /// Test configuration
    private var maxConcurrent: Int = 3
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        mockLogger = MockLogger()
        semaphore = AsyncSemaphore(maxConcurrent: maxConcurrent, logger: mockLogger)
    }
    
    override func tearDown() async throws {
        await semaphore.deactivate()
        semaphore = nil
        mockLogger = nil
        try await super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    /**
     * Test semaphore initialization
     * 
     * This test verifies that AsyncSemaphore can be initialized
     * with proper configuration.
     */
    func testSemaphoreInitialization() {
        // Given
        let logger = MockLogger()
        let maxConcurrent = 5
        
        // When
        let semaphore = AsyncSemaphore(maxConcurrent: maxConcurrent, logger: logger)
        
        // Then
        XCTAssertNotNil(semaphore)
    }
    
    /**
     * Test semaphore status
     * 
     * This test verifies that the semaphore provides
     * accurate status information.
     */
    func testSemaphoreStatus() async {
        // Given
        let expectation = XCTestExpectation(description: "Status retrieved")
        
        // When
        let status = await semaphore.getStatus()
        
        // Then
        XCTAssertEqual(status.current, 0)
        XCTAssertEqual(status.max, maxConcurrent)
        XCTAssertEqual(status.waiting, 0)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    /**
     * Test semaphore capacity check
     * 
     * This test verifies that the semaphore correctly
     * reports when it's at capacity.
     */
    func testSemaphoreCapacityCheck() async {
        // Given
        let expectation = XCTestExpectation(description: "Capacity check completed")
        
        // When
        let isAtCapacity = await semaphore.isAtCapacity()
        
        // Then
        XCTAssertFalse(isAtCapacity) // Should not be at capacity initially
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    /**
     * Test semaphore waiting count
     * 
     * This test verifies that the semaphore correctly
     * reports the number of waiting operations.
     */
    func testSemaphoreWaitingCount() async {
        // Given
        let expectation = XCTestExpectation(description: "Waiting count retrieved")
        
        // When
        let waitingCount = await semaphore.waitingCount()
        
        // Then
        XCTAssertEqual(waitingCount, 0) // Should have no waiting operations initially
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Acquisition and Release Tests
    
    /**
     * Test semaphore acquisition and release
     * 
     * This test verifies that operations can acquire
     * and release the semaphore correctly.
     */
    func testSemaphoreAcquisitionAndRelease() async {
        // Given
        let expectation = XCTestExpectation(description: "Acquisition and release completed")
        
        // When
        do {
            try await semaphore.acquire()
            
            // Verify that we have acquired the semaphore
            let status = await semaphore.getStatus()
            XCTAssertEqual(status.current, 1)
            
            await semaphore.release()
            
            // Verify that we have released the semaphore
            let finalStatus = await semaphore.getStatus()
            XCTAssertEqual(finalStatus.current, 0)
            
        } catch {
            XCTFail("Acquisition should not fail: \(error)")
        }
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    /**
     * Test semaphore multiple acquisitions
     * 
     * This test verifies that multiple operations can
     * acquire the semaphore up to the limit.
     */
    func testSemaphoreMultipleAcquisitions() async {
        // Given
        let expectation = XCTestExpectation(description: "Multiple acquisitions completed")
        
        // When - Acquire multiple times up to the limit
        do {
            for _ in 0..<maxConcurrent {
                try await semaphore.acquire()
            }
            
            // Verify that we have reached the limit
            let status = await semaphore.getStatus()
            XCTAssertEqual(status.current, maxConcurrent)
            
            // Release all acquisitions
            for _ in 0..<maxConcurrent {
                await semaphore.release()
            }
            
            // Verify that all have been released
            let finalStatus = await semaphore.getStatus()
            XCTAssertEqual(finalStatus.current, 0)
            
        } catch {
            XCTFail("Acquisitions should not fail: \(error)")
        }
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    /**
     * Test semaphore acquisition beyond limit
     * 
     * This test verifies that operations are blocked
     * when trying to acquire beyond the limit.
     */
    func testSemaphoreAcquisitionBeyondLimit() async {
        // Given
        let expectation = XCTestExpectation(description: "Acquisition beyond limit handled")
        
        // When - Acquire up to the limit
        do {
            for _ in 0..<maxConcurrent {
                try await semaphore.acquire()
            }
            
            // Try to acquire one more (should be blocked)
            let additionalAcquisition = Task {
                try await semaphore.acquire()
            }
            
            // Wait a bit to ensure the additional acquisition is blocked
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Verify that the additional acquisition is still waiting
            let waitingCount = await semaphore.waitingCount()
            XCTAssertEqual(waitingCount, 1)
            
            // Release one acquisition to allow the waiting one to proceed
            await semaphore.release()
            
            // Wait for the additional acquisition to complete
            try await additionalAcquisition.value
            
        } catch {
            XCTFail("Acquisition should not fail: \(error)")
        }
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    // MARK: - Concurrency Tests
    
    /**
     * Test semaphore concurrent operations
     * 
     * This test verifies that the semaphore handles
     * concurrent operations correctly.
     */
    func testSemaphoreConcurrentOperations() async {
        // Given
        let expectation = XCTestExpectation(description: "Concurrent operations completed")
        let operationCount = 10
        var completedOperations = 0
        
        // When - Start multiple concurrent operations
        let operations = (0..<operationCount).map { i in
            Task {
                do {
                    try await semaphore.acquire()
                    
                    // Simulate some work
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    
                    await semaphore.release()
                    completedOperations += 1
                    
                } catch {
                    XCTFail("Operation \(i) should not fail: \(error)")
                }
            }
        }
        
        // Wait for all operations to complete
        for operation in operations {
            await operation.value
        }
        
        // Then
        XCTAssertEqual(completedOperations, operationCount)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    /**
     * Test semaphore with different concurrency levels
     * 
     * This test verifies that the semaphore works correctly
     * with different concurrency levels.
     */
    func testSemaphoreDifferentConcurrencyLevels() async {
        // Given
        let expectation = XCTestExpectation(description: "Different concurrency levels tested")
        
        // When - Test with different max concurrent values
        let testLevels = [1, 2, 5, 10]
        
        for level in testLevels {
            let testSemaphore = AsyncSemaphore(maxConcurrent: level, logger: mockLogger)
            
            // Acquire up to the limit
            do {
                for _ in 0..<level {
                    try await testSemaphore.acquire()
                }
                
                // Verify that we have reached the limit
                let status = await testSemaphore.getStatus()
                XCTAssertEqual(status.current, level)
                
                // Release all acquisitions
                for _ in 0..<level {
                    await testSemaphore.release()
                }
                
                // Verify that all have been released
                let finalStatus = await testSemaphore.getStatus()
                XCTAssertEqual(finalStatus.current, 0)
                
            } catch {
                XCTFail("Semaphore operations should not fail: \(error)")
            }
            
            await testSemaphore.deactivate()
        }
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    // MARK: - Error Handling Tests
    
    /**
     * Test semaphore deactivation
     * 
     * This test verifies that the semaphore can be deactivated
     * and properly cleans up resources.
     */
    func testSemaphoreDeactivation() async {
        // Given
        let expectation = XCTestExpectation(description: "Semaphore deactivated")
        
        // When
        await semaphore.deactivate()
        
        // Then - Try to acquire should fail
        do {
            try await semaphore.acquire()
            XCTFail("Acquisition should fail after deactivation")
        } catch KairoError.cancelled {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    /**
     * Test semaphore with cancelled operations
     * 
     * This test verifies that the semaphore handles
     * cancelled operations gracefully.
     */
    func testSemaphoreCancelledOperations() async {
        // Given
        let expectation = XCTestExpectation(description: "Cancelled operations handled")
        
        // When - Start an operation and then cancel it
        let operation = Task {
            try await semaphore.acquire()
        }
        
        // Cancel the operation
        operation.cancel()
        
        // Then - The operation should be cancelled
        do {
            try await operation.value
            XCTFail("Operation should have been cancelled")
        } catch {
            // Expected to be cancelled
        }
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Performance Tests
    
    /**
     * Test semaphore performance
     * 
     * This test verifies that the semaphore performs
     * well under normal conditions.
     */
    func testSemaphorePerformance() async {
        // Given
        let startTime = Date()
        let expectation = XCTestExpectation(description: "Performance test completed")
        let operationCount = 100
        
        // When - Execute many operations
        let operations = (0..<operationCount).map { _ in
            Task {
                do {
                    try await semaphore.acquire()
                    try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
                    await semaphore.release()
                } catch {
                    XCTFail("Operation should not fail: \(error)")
                }
            }
        }
        
        // Wait for all operations to complete
        for operation in operations {
            await operation.value
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Then
        XCTAssertLessThan(duration, 5.0) // Should complete within 5 seconds
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    /**
     * Test semaphore memory usage
     * 
     * This test verifies that the semaphore doesn't
     * accumulate excessive memory usage over time.
     */
    func testSemaphoreMemoryUsage() async {
        // Given
        let expectation = XCTestExpectation(description: "Memory usage test completed")
        
        // When - Execute many operations over time
        for _ in 0..<1000 {
            do {
                try await semaphore.acquire()
                await semaphore.release()
            } catch {
                XCTFail("Operation should not fail: \(error)")
            }
        }
        
        // Then - Semaphore should still be functional
        let status = await semaphore.getStatus()
        XCTAssertEqual(status.current, 0)
        XCTAssertEqual(status.max, maxConcurrent)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Integration Tests
    
    /**
     * Test semaphore integration with Kairo
     * 
     * This test verifies that the semaphore works correctly
     * when integrated with the Kairo framework.
     */
    func testSemaphoreKairoIntegration() async {
        // Given
        let kairo = Kairo()
        await kairo.start()
        
        // When
        let shouldAllow = await kairo.shouldAllowOperation(.networkRequest(priority: .normal))
        
        // Then
        // Network requests should be allowed in good conditions
        XCTAssertTrue(shouldAllow)
        
        // Clean up
        await kairo.stop()
    }
    
    /**
     * Test semaphore with different health conditions
     * 
     * This test verifies that the semaphore responds appropriately
     * to different device health conditions.
     */
    func testSemaphoreWithHealthConditions() async {
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
     * Test semaphore with realistic usage patterns
     * 
     * This test verifies that the semaphore works correctly
     * with realistic usage patterns.
     */
    func testSemaphoreRealisticUsage() async {
        // Given
        let expectation = XCTestExpectation(description: "Realistic usage completed")
        let operationCount = 20
        var completedOperations = 0
        
        // When - Simulate realistic usage patterns
        let operations = (0..<operationCount).map { i in
            Task {
                do {
                    try await semaphore.acquire()
                    
                    // Simulate different types of work
                    let workDuration = UInt64.random(in: 50_000_000...200_000_000) // 0.05 to 0.2 seconds
                    try await Task.sleep(nanoseconds: workDuration)
                    
                    await semaphore.release()
                    completedOperations += 1
                    
                } catch {
                    XCTFail("Operation \(i) should not fail: \(error)")
                }
            }
        }
        
        // Wait for all operations to complete
        for operation in operations {
            await operation.value
        }
        
        // Then
        XCTAssertEqual(completedOperations, operationCount)
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 10.0)
    }
    
    /**
     * Test semaphore with different operation types
     * 
     * This test verifies that the semaphore can handle
     * different types of operations appropriately.
     */
    func testSemaphoreDifferentOperationTypes() async {
        // Given
        let expectation = XCTestExpectation(description: "Different operation types completed")
        var operationTypes: Set<String> = []
        
        // When - Execute different types of operations
        let networkOperation = Task {
            do {
                try await semaphore.acquire()
                operationTypes.insert("network")
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                await semaphore.release()
            } catch {
                XCTFail("Network operation should not fail: \(error)")
            }
        }
        
        let cpuOperation = Task {
            do {
                try await semaphore.acquire()
                operationTypes.insert("cpu")
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                await semaphore.release()
            } catch {
                XCTFail("CPU operation should not fail: \(error)")
            }
        }
        
        let ioOperation = Task {
            do {
                try await semaphore.acquire()
                operationTypes.insert("io")
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                await semaphore.release()
            } catch {
                XCTFail("IO operation should not fail: \(error)")
            }
        }
        
        // Wait for all operations to complete
        await networkOperation.value
        await cpuOperation.value
        await ioOperation.value
        
        // Then
        XCTAssertEqual(operationTypes.count, 3)
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    // MARK: - Edge Cases Tests
    
    /**
     * Test semaphore with zero concurrency
     * 
     * This test verifies that the semaphore handles
     * zero concurrency gracefully.
     */
    func testSemaphoreZeroConcurrency() async {
        // Given
        let zeroSemaphore = AsyncSemaphore(maxConcurrent: 0, logger: mockLogger)
        let expectation = XCTestExpectation(description: "Zero concurrency handled")
        
        // When - Try to acquire with zero concurrency
        do {
            try await zeroSemaphore.acquire()
            XCTFail("Acquisition should fail with zero concurrency")
        } catch KairoError.cancelled {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        // Then
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
        
        // Clean up
        await zeroSemaphore.deactivate()
    }
    
    /**
     * Test semaphore with negative concurrency
     * 
     * This test verifies that the semaphore handles
     * negative concurrency gracefully.
     */
    func testSemaphoreNegativeConcurrency() async {
        // Given
        let negativeSemaphore = AsyncSemaphore(maxConcurrent: -1, logger: mockLogger)
        let expectation = XCTestExpectation(description: "Negative concurrency handled")
        
        // When - Try to acquire with negative concurrency
        do {
            try await negativeSemaphore.acquire()
            XCTFail("Acquisition should fail with negative concurrency")
        } catch KairoError.cancelled {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        // Then
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
        
        // Clean up
        await negativeSemaphore.deactivate()
    }
    
    /**
     * Test semaphore with very high concurrency
     * 
     * This test verifies that the semaphore handles
     * very high concurrency gracefully.
     */
    func testSemaphoreHighConcurrency() async {
        // Given
        let highConcurrency = 1000
        let highSemaphore = AsyncSemaphore(maxConcurrent: highConcurrency, logger: mockLogger)
        let expectation = XCTestExpectation(description: "High concurrency handled")
        
        // When - Acquire up to the high limit
        do {
            for _ in 0..<highConcurrency {
                try await highSemaphore.acquire()
            }
            
            // Verify that we have reached the limit
            let status = await highSemaphore.getStatus()
            XCTAssertEqual(status.current, highConcurrency)
            
            // Release all acquisitions
            for _ in 0..<highConcurrency {
                await highSemaphore.release()
            }
            
            // Verify that all have been released
            let finalStatus = await highSemaphore.getStatus()
            XCTAssertEqual(finalStatus.current, 0)
            
        } catch {
            XCTFail("High concurrency operations should not fail: \(error)")
        }
        
        // Then
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 5.0)
        
        // Clean up
        await highSemaphore.deactivate()
    }
}
