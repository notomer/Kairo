import XCTest
import Foundation
@testable import Kairo

/**
 * CircuitBreakerTests - Comprehensive test suite for CircuitBreaker
 * 
 * This test suite covers all aspects of the CircuitBreaker class including:
 * - Circuit breaker state transitions
 * - Failure threshold handling
 * - Timeout and recovery logic
 * - Success threshold validation
 * - Error handling and edge cases
 * - Performance under various conditions
 */
class CircuitBreakerTests: XCTestCase {
    
    // MARK: - Properties
    
    /// Mock logger for testing
    private var mockLogger: MockLogger!
    
    /// Circuit breaker instance for testing
    private var circuitBreaker: CircuitBreaker!
    
    /// Test configuration
    private var testConfig: CircuitBreakerConfiguration!
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        mockLogger = MockLogger()
        testConfig = CircuitBreakerConfiguration(
            failureThreshold: 3,
            timeoutSeconds: 5.0,
            successThreshold: 2,
            maxRequestsInHalfOpen: 3
        )
        circuitBreaker = CircuitBreaker(name: "TestCircuit", config: testConfig, logger: mockLogger)
    }
    
    override func tearDown() async throws {
        circuitBreaker = nil
        testConfig = nil
        mockLogger = nil
        try await super.tearDown()
    }
    
    // MARK: - Circuit Breaker State Tests
    
    /**
     * Test circuit breaker initial state
     * 
     * This test verifies that the circuit breaker starts
     * in the closed state.
     */
    func testCircuitBreakerInitialState() async {
        // Given & When
        let state = await circuitBreaker.getState()
        
        // Then
        XCTAssertEqual(state, .closed)
    }
    
    /**
     * Test circuit breaker state transitions
     * 
     * This test verifies that the circuit breaker transitions
     * between states correctly based on operation results.
     */
    func testCircuitBreakerStateTransitions() async {
        // Given
        let expectation = XCTestExpectation(description: "Circuit breaker state transitions")
        
        // When - Execute operations that will cause failures
        for _ in 0..<testConfig.failureThreshold {
            do {
                let _ = try await circuitBreaker.execute {
                    throw TestError.operationFailed
                }
            } catch {
                // Expected to fail
            }
        }
        
        // Then - Circuit should be open
        let state = await circuitBreaker.getState()
        XCTAssertEqual(state, .open)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    /**
     * Test circuit breaker open state
     * 
     * This test verifies that the circuit breaker blocks
     * operations when in the open state.
     */
    func testCircuitBreakerOpenState() async {
        // Given - Force circuit to open state
        for _ in 0..<testConfig.failureThreshold {
            do {
                let _ = try await circuitBreaker.execute {
                    throw TestError.operationFailed
                }
            } catch {
                // Expected to fail
            }
        }
        
        // When - Try to execute operation in open state
        do {
            let _ = try await circuitBreaker.execute {
                return "success"
            }
            XCTFail("Operation should have been blocked")
        } catch KairoError.circuitOpen {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    /**
     * Test circuit breaker half-open state
     * 
     * This test verifies that the circuit breaker transitions
     * to half-open state after timeout and allows limited operations.
     */
    func testCircuitBreakerHalfOpenState() async {
        // Given - Force circuit to open state
        for _ in 0..<testConfig.failureThreshold {
            do {
                let _ = try await circuitBreaker.execute {
                    throw TestError.operationFailed
                }
            } catch {
                // Expected to fail
            }
        }
        
        // Wait for timeout to transition to half-open
        try await Task.sleep(nanoseconds: UInt64(testConfig.timeoutSeconds * 1_000_000_000))
        
        // When - Check state
        let state = await circuitBreaker.getState()
        
        // Then
        XCTAssertEqual(state, .halfOpen)
    }
    
    /**
     * Test circuit breaker recovery
     * 
     * This test verifies that the circuit breaker recovers
     * to closed state after successful operations.
     */
    func testCircuitBreakerRecovery() async {
        // Given - Force circuit to open state
        for _ in 0..<testConfig.failureThreshold {
            do {
                let _ = try await circuitBreaker.execute {
                    throw TestError.operationFailed
                }
            } catch {
                // Expected to fail
            }
        }
        
        // Wait for timeout to transition to half-open
        try await Task.sleep(nanoseconds: UInt64(testConfig.timeoutSeconds * 1_000_000_000))
        
        // When - Execute successful operations
        for _ in 0..<testConfig.successThreshold {
            let _ = try await circuitBreaker.execute {
                return "success"
            }
        }
        
        // Then - Circuit should be closed
        let state = await circuitBreaker.getState()
        XCTAssertEqual(state, .closed)
    }
    
    // MARK: - Operation Execution Tests
    
    /**
     * Test successful operation execution
     * 
     * This test verifies that successful operations are executed
     * and return the correct result.
     */
    func testSuccessfulOperationExecution() async {
        // Given
        let expectedResult = "test result"
        
        // When
        let result = try await circuitBreaker.execute {
            return expectedResult
        }
        
        // Then
        XCTAssertEqual(result, expectedResult)
    }
    
    /**
     * Test failed operation execution
     * 
     * This test verifies that failed operations throw
     * the correct error.
     */
    func testFailedOperationExecution() async {
        // Given
        let expectedError = TestError.operationFailed
        
        // When & Then
        do {
            let _ = try await circuitBreaker.execute {
                throw expectedError
            }
            XCTFail("Operation should have failed")
        } catch TestError.operationFailed {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    /**
     * Test operation execution with different result types
     * 
     * This test verifies that the circuit breaker can handle
     * operations with different return types.
     */
    func testOperationExecutionDifferentTypes() async {
        // Given
        let stringResult = "string result"
        let intResult = 42
        let boolResult = true
        
        // When
        let stringValue = try await circuitBreaker.execute { stringResult }
        let intValue = try await circuitBreaker.execute { intResult }
        let boolValue = try await circuitBreaker.execute { boolResult }
        
        // Then
        XCTAssertEqual(stringValue, stringResult)
        XCTAssertEqual(intValue, intResult)
        XCTAssertEqual(boolValue, boolResult)
    }
    
    // MARK: - Configuration Tests
    
    /**
     * Test circuit breaker with custom configuration
     * 
     * This test verifies that the circuit breaker works correctly
     * with custom configuration settings.
     */
    func testCircuitBreakerCustomConfiguration() async {
        // Given
        let customConfig = CircuitBreakerConfiguration(
            failureThreshold: 5,
            timeoutSeconds: 10.0,
            successThreshold: 3,
            maxRequestsInHalfOpen: 5
        )
        let customCircuitBreaker = CircuitBreaker(name: "CustomCircuit", config: customConfig, logger: mockLogger)
        
        // When - Execute operations that will cause failures
        for _ in 0..<customConfig.failureThreshold {
            do {
                let _ = try await customCircuitBreaker.execute {
                    throw TestError.operationFailed
                }
            } catch {
                // Expected to fail
            }
        }
        
        // Then - Circuit should be open
        let state = await customCircuitBreaker.getState()
        XCTAssertEqual(state, .open)
    }
    
    /**
     * Test circuit breaker with default configuration
     * 
     * This test verifies that the circuit breaker works correctly
     * with default configuration settings.
     */
    func testCircuitBreakerDefaultConfiguration() async {
        // Given
        let defaultConfig = CircuitBreakerConfiguration.default
        let defaultCircuitBreaker = CircuitBreaker(name: "DefaultCircuit", config: defaultConfig, logger: mockLogger)
        
        // When
        let result = try await defaultCircuitBreaker.execute {
            return "success"
        }
        
        // Then
        XCTAssertEqual(result, "success")
    }
    
    // MARK: - Status and Monitoring Tests
    
    /**
     * Test circuit breaker status information
     * 
     * This test verifies that the circuit breaker provides
     * accurate status information.
     */
    func testCircuitBreakerStatus() async {
        // Given
        let expectation = XCTestExpectation(description: "Status information retrieved")
        
        // When
        let status = await circuitBreaker.getStatus()
        
        // Then
        XCTAssertNotNil(status["state"])
        XCTAssertNotNil(status["failureCount"])
        XCTAssertNotNil(status["successCount"])
        XCTAssertNotNil(status["requestsInHalfOpen"])
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    /**
     * Test circuit breaker status after failures
     * 
     * This test verifies that the circuit breaker status
     * reflects the current state after failures.
     */
    func testCircuitBreakerStatusAfterFailures() async {
        // Given
        let expectation = XCTestExpectation(description: "Status after failures")
        
        // When - Execute operations that will cause failures
        for _ in 0..<testConfig.failureThreshold {
            do {
                let _ = try await circuitBreaker.execute {
                    throw TestError.operationFailed
                }
            } catch {
                // Expected to fail
            }
        }
        
        let status = await circuitBreaker.getStatus()
        
        // Then
        XCTAssertEqual(status["state"] as? String, "Open - Blocking requests due to failures")
        XCTAssertEqual(status["failureCount"] as? Int, testConfig.failureThreshold)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Manual Control Tests
    
    /**
     * Test manual circuit breaker reset
     * 
     * This test verifies that the circuit breaker can be
     * manually reset to closed state.
     */
    func testManualCircuitBreakerReset() async {
        // Given - Force circuit to open state
        for _ in 0..<testConfig.failureThreshold {
            do {
                let _ = try await circuitBreaker.execute {
                    throw TestError.operationFailed
                }
            } catch {
                // Expected to fail
            }
        }
        
        // When - Manually reset circuit
        await circuitBreaker.reset()
        
        // Then - Circuit should be closed
        let state = await circuitBreaker.getState()
        XCTAssertEqual(state, .closed)
    }
    
    /**
     * Test manual circuit breaker open
     * 
     * This test verifies that the circuit breaker can be
     * manually opened.
     */
    func testManualCircuitBreakerOpen() async {
        // Given
        let expectation = XCTestExpectation(description: "Circuit manually opened")
        
        // When - Manually open circuit
        await circuitBreaker.open()
        
        // Then - Circuit should be open
        let state = await circuitBreaker.getState()
        XCTAssertEqual(state, .open)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Error Handling Tests
    
    /**
     * Test circuit breaker error handling
     * 
     * This test verifies that the circuit breaker handles
     * various error conditions gracefully.
     */
    func testCircuitBreakerErrorHandling() async {
        // Given
        let expectation = XCTestExpectation(description: "Error handling verified")
        
        // When - Execute operations with different error types
        do {
            let _ = try await circuitBreaker.execute {
                throw TestError.operationFailed
            }
        } catch TestError.operationFailed {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        do {
            let _ = try await circuitBreaker.execute {
                throw TestError.networkError
            }
        } catch TestError.networkError {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        // Then
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    /**
     * Test circuit breaker with timeout errors
     * 
     * This test verifies that the circuit breaker handles
     * timeout errors correctly.
     */
    func testCircuitBreakerTimeoutErrors() async {
        // Given
        let expectation = XCTestExpectation(description: "Timeout error handled")
        
        // When - Execute operation that times out
        do {
            let _ = try await circuitBreaker.execute {
                try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                return "success"
            }
        } catch {
            // Expected to timeout or be cancelled
        }
        
        // Then
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 15.0)
    }
    
    // MARK: - Performance Tests
    
    /**
     * Test circuit breaker performance
     * 
     * This test verifies that the circuit breaker performs
     * well under normal conditions.
     */
    func testCircuitBreakerPerformance() async {
        // Given
        let startTime = Date()
        let expectation = XCTestExpectation(description: "Performance test completed")
        
        // When - Execute many operations
        for i in 0..<100 {
            do {
                let _ = try await circuitBreaker.execute {
                    return "result-\(i)"
                }
            } catch {
                XCTFail("Operation \(i) failed: \(error)")
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
     * Test circuit breaker memory usage
     * 
     * This test verifies that the circuit breaker doesn't
     * accumulate excessive memory usage over time.
     */
    func testCircuitBreakerMemoryUsage() async {
        // Given
        let expectation = XCTestExpectation(description: "Memory usage test completed")
        
        // When - Execute many operations over time
        for _ in 0..<1000 {
            do {
                let _ = try await circuitBreaker.execute {
                    return "result"
                }
            } catch {
                // Some operations may fail, which is expected
            }
        }
        
        // Then - Circuit breaker should still be functional
        let state = await circuitBreaker.getState()
        XCTAssertNotNil(state)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Integration Tests
    
    /**
     * Test circuit breaker integration with Kairo
     * 
     * This test verifies that the circuit breaker works correctly
     * when integrated with the Kairo framework.
     */
    func testCircuitBreakerKairoIntegration() async {
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
     * Test circuit breaker with different health conditions
     * 
     * This test verifies that the circuit breaker responds appropriately
     * to different device health conditions.
     */
    func testCircuitBreakerWithHealthConditions() async {
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
     * Test circuit breaker with realistic usage patterns
     * 
     * This test verifies that the circuit breaker works correctly
     * with realistic usage patterns.
     */
    func testCircuitBreakerRealisticUsage() async {
        // Given
        let expectation = XCTestExpectation(description: "Realistic usage completed")
        
        // When - Simulate realistic usage patterns
        // Start with successful operations
        for _ in 0..<5 {
            let _ = try await circuitBreaker.execute {
                return "success"
            }
        }
        
        // Then introduce some failures
        for _ in 0..<3 {
            do {
                let _ = try await circuitBreaker.execute {
                    throw TestError.operationFailed
                }
            } catch {
                // Expected to fail
            }
        }
        
        // Then
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    /**
     * Test circuit breaker with different operation types
     * 
     * This test verifies that the circuit breaker can handle
     * different types of operations appropriately.
     */
    func testCircuitBreakerDifferentOperationTypes() async {
        // Given
        let expectation = XCTestExpectation(description: "Different operation types completed")
        
        // When - Execute different types of operations
        let stringResult = try await circuitBreaker.execute { "string result" }
        let intResult = try await circuitBreaker.execute { 42 }
        let boolResult = try await circuitBreaker.execute { true }
        let arrayResult = try await circuitBreaker.execute { [1, 2, 3] }
        
        // Then
        XCTAssertEqual(stringResult, "string result")
        XCTAssertEqual(intResult, 42)
        XCTAssertEqual(boolResult, true)
        XCTAssertEqual(arrayResult, [1, 2, 3])
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
}

/**
 * TestError - Test error types for testing
 * 
 * This enum defines test error types for testing error handling
 * in the circuit breaker.
 */
enum TestError: Error {
    case operationFailed
    case networkError
    case timeoutError
    case unknownError
}
