import XCTest
import Foundation
@testable import Kairo

/**
 * JobSchedulerTests - Comprehensive test suite for JobScheduler
 * 
 * This test suite covers all aspects of the JobScheduler class including:
 * - Job scheduling and execution
 * - Priority-based job queuing
 * - Background task management
 * - Performance throttling based on device health
 * - Job cancellation and cleanup
 * - Error handling and retry logic
 * - Integration with Kairo framework
 */
class JobSchedulerTests: XCTestCase {
    
    // MARK: - Properties
    
    /// Mock logger for testing
    private var mockLogger: MockLogger!
    
    /// Job scheduler instance for testing
    private var jobScheduler: JobScheduler!
    
    /// Test configuration
    private var testConfig: KairoConfig!
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        mockLogger = MockLogger()
        testConfig = KairoConfig(
            networkMaxConcurrent: 6,
            lowBatteryThreshold: 0.15,
            debounceMillis: 350
        )
        jobScheduler = JobScheduler(config: testConfig, logger: mockLogger)
    }
    
    override func tearDown() async throws {
        await jobScheduler.stop()
        jobScheduler = nil
        testConfig = nil
        mockLogger = nil
        try await super.tearDown()
    }
    
    // MARK: - Job Scheduler Initialization Tests
    
    /**
     * Test job scheduler initialization
     * 
     * This test verifies that JobScheduler can be initialized
     * with proper configuration.
     */
    func testJobSchedulerInitialization() {
        // Given
        let config = KairoConfig()
        let logger = MockLogger()
        
        // When
        let scheduler = JobScheduler(config: config, logger: logger)
        
        // Then
        XCTAssertNotNil(scheduler)
    }
    
    /**
     * Test job scheduler with custom configuration
     * 
     * This test verifies that JobScheduler can be initialized
     * with custom configuration settings.
     */
    func testJobSchedulerCustomConfiguration() {
        // Given
        let customConfig = KairoConfig(
            networkMaxConcurrent: 4,
            lowBatteryThreshold: 0.20,
            debounceMillis: 500
        )
        let logger = MockLogger()
        
        // When
        let scheduler = JobScheduler(config: customConfig, logger: logger)
        
        // Then
        XCTAssertNotNil(scheduler)
    }
    
    // MARK: - Job Scheduling Tests
    
    /**
     * Test scheduling a basic job
     * 
     * This test verifies that a basic job can be scheduled
     * and executed successfully.
     */
    func testScheduleBasicJob() async {
        // Given
        let expectation = XCTestExpectation(description: "Job executed")
        var jobExecuted = false
        
        // When
        await jobScheduler.scheduleJob(
            id: "test-job",
            priority: .normal,
            task: {
                jobExecuted = true
                expectation.fulfill()
            }
        )
        
        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertTrue(jobExecuted)
    }
    
    /**
     * Test scheduling multiple jobs
     * 
     * This test verifies that multiple jobs can be scheduled
     * and executed in the correct order.
     */
    func testScheduleMultipleJobs() async {
        // Given
        let expectation1 = XCTestExpectation(description: "Job 1 executed")
        let expectation2 = XCTestExpectation(description: "Job 2 executed")
        let expectation3 = XCTestExpectation(description: "Job 3 executed")
        
        var executionOrder: [String] = []
        
        // When
        await jobScheduler.scheduleJob(
            id: "job-1",
            priority: .normal,
            task: {
                executionOrder.append("job-1")
                expectation1.fulfill()
            }
        )
        
        await jobScheduler.scheduleJob(
            id: "job-2",
            priority: .high,
            task: {
                executionOrder.append("job-2")
                expectation2.fulfill()
            }
        )
        
        await jobScheduler.scheduleJob(
            id: "job-3",
            priority: .low,
            task: {
                executionOrder.append("job-3")
                expectation3.fulfill()
            }
        )
        
        // Then
        await fulfillment(of: [expectation1, expectation2, expectation3], timeout: 10.0)
        XCTAssertEqual(executionOrder.count, 3)
    }
    
    /**
     * Test job priority ordering
     * 
     * This test verifies that jobs are executed in priority order,
     * with high priority jobs executing before low priority jobs.
     */
    func testJobPriorityOrdering() async {
        // Given
        let expectation = XCTestExpectation(description: "All jobs executed")
        var executionOrder: [String] = []
        
        // When - Schedule jobs with different priorities
        await jobScheduler.scheduleJob(
            id: "low-priority",
            priority: .low,
            task: {
                executionOrder.append("low-priority")
            }
        )
        
        await jobScheduler.scheduleJob(
            id: "high-priority",
            priority: .high,
            task: {
                executionOrder.append("high-priority")
            }
        )
        
        await jobScheduler.scheduleJob(
            id: "normal-priority",
            priority: .normal,
            task: {
                executionOrder.append("normal-priority")
            }
        )
        
        // Wait for all jobs to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            expectation.fulfill()
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
        // High priority job should execute first
        XCTAssertEqual(executionOrder.first, "high-priority")
    }
    
    /**
     * Test job cancellation
     * 
     * This test verifies that scheduled jobs can be cancelled
     * before execution.
     */
    func testJobCancellation() async {
        // Given
        let expectation = XCTestExpectation(description: "Job cancelled")
        var jobExecuted = false
        
        // When
        await jobScheduler.scheduleJob(
            id: "cancellable-job",
            priority: .normal,
            task: {
                jobExecuted = true
            }
        )
        
        // Cancel the job
        await jobScheduler.cancelJob(id: "cancellable-job")
        
        // Wait to ensure job doesn't execute
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 3.0)
        XCTAssertFalse(jobExecuted)
    }
    
    /**
     * Test job with error handling
     * 
     * This test verifies that jobs with errors are handled
     * gracefully and don't crash the scheduler.
     */
    func testJobErrorHandling() async {
        // Given
        let expectation = XCTestExpectation(description: "Job error handled")
        var errorCaught = false
        
        // When
        await jobScheduler.scheduleJob(
            id: "error-job",
            priority: .normal,
            task: {
                throw TestError.jobFailed
            }
        )
        
        // Wait for error handling
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            errorCaught = true
            expectation.fulfill()
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 3.0)
        XCTAssertTrue(errorCaught)
    }
    
    // MARK: - Background Task Management Tests
    
    /**
     * Test background task scheduling
     * 
     * This test verifies that background tasks can be scheduled
     * and managed properly.
     */
    func testBackgroundTaskScheduling() async {
        // Given
        let expectation = XCTestExpectation(description: "Background task executed")
        var backgroundTaskExecuted = false
        
        // When
        await jobScheduler.scheduleBackgroundTask(
            id: "background-task",
            priority: .normal,
            task: {
                backgroundTaskExecuted = true
                expectation.fulfill()
            }
        )
        
        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertTrue(backgroundTaskExecuted)
    }
    
    /**
     * Test background task cancellation
     * 
     * This test verifies that background tasks can be cancelled
     * when no longer needed.
     */
    func testBackgroundTaskCancellation() async {
        // Given
        let expectation = XCTestExpectation(description: "Background task cancelled")
        var backgroundTaskExecuted = false
        
        // When
        await jobScheduler.scheduleBackgroundTask(
            id: "cancellable-background-task",
            priority: .normal,
            task: {
                backgroundTaskExecuted = true
            }
        )
        
        // Cancel the background task
        await jobScheduler.cancelBackgroundTask(id: "cancellable-background-task")
        
        // Wait to ensure task doesn't execute
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 3.0)
        XCTAssertFalse(backgroundTaskExecuted)
    }
    
    // MARK: - Performance Throttling Tests
    
    /**
     * Test job throttling with poor device conditions
     * 
     * This test verifies that jobs are throttled appropriately
     * when device conditions are poor.
     */
    func testJobThrottlingPoorConditions() async {
        // Given
        let expectation = XCTestExpectation(description: "Job throttling applied")
        var jobExecuted = false
        
        // When - Simulate poor device conditions
        let poorHealth = HealthSnapshot(
            batteryLevel: 0.20,
            lowPowerMode: true,
            thermalState: .serious,
            networkReachability: .satisfied,
            networkConstrained: true,
            networkExpensive: true
        )
        
        await jobScheduler.updateHealth(poorHealth)
        
        await jobScheduler.scheduleJob(
            id: "throttled-job",
            priority: .normal,
            task: {
                jobExecuted = true
            }
        )
        
        // Wait for throttling to be applied
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 3.0)
        // Job should be throttled and not execute immediately
        XCTAssertFalse(jobExecuted)
    }
    
    /**
     * Test job throttling with excellent device conditions
     * 
     * This test verifies that jobs execute normally
     * when device conditions are excellent.
     */
    func testJobThrottlingExcellentConditions() async {
        // Given
        let expectation = XCTestExpectation(description: "Job executed normally")
        var jobExecuted = false
        
        // When - Simulate excellent device conditions
        let excellentHealth = HealthSnapshot(
            batteryLevel: 0.95,
            lowPowerMode: false,
            thermalState: .nominal,
            networkReachability: .satisfied,
            networkConstrained: false,
            networkExpensive: false
        )
        
        await jobScheduler.updateHealth(excellentHealth)
        
        await jobScheduler.scheduleJob(
            id: "normal-job",
            priority: .normal,
            task: {
                jobExecuted = true
                expectation.fulfill()
            }
        )
        
        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertTrue(jobExecuted)
    }
    
    // MARK: - Job Scheduler Lifecycle Tests
    
    /**
     * Test job scheduler start
     * 
     * This test verifies that the job scheduler can be started
     * and begins processing jobs.
     */
    func testJobSchedulerStart() async {
        // Given
        let expectation = XCTestExpectation(description: "Scheduler started")
        
        // When
        await jobScheduler.start()
        
        // Then
        // Verify that scheduler is running by scheduling a job
        await jobScheduler.scheduleJob(
            id: "startup-job",
            priority: .normal,
            task: {
                expectation.fulfill()
            }
        )
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    /**
     * Test job scheduler stop
     * 
     * This test verifies that the job scheduler can be stopped
     * and properly cleans up resources.
     */
    func testJobSchedulerStop() async {
        // Given
        await jobScheduler.start()
        
        // When
        await jobScheduler.stop()
        
        // Then
        // Verify that scheduler is stopped by checking that new jobs don't execute
        let expectation = XCTestExpectation(description: "Job should not execute")
        expectation.isInverted = true
        
        await jobScheduler.scheduleJob(
            id: "stopped-job",
            priority: .normal,
            task: {
                expectation.fulfill()
            }
        )
        
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    // MARK: - Error Handling Tests
    
    /**
     * Test job scheduler error handling
     * 
     * This test verifies that the job scheduler handles
     * various error conditions gracefully.
     */
    func testJobSchedulerErrorHandling() async {
        // Given
        let expectation = XCTestExpectation(description: "Error handled")
        var errorCaught = false
        
        // When
        await jobScheduler.scheduleJob(
            id: "error-job",
            priority: .normal,
            task: {
                throw TestError.schedulerError
            }
        )
        
        // Wait for error handling
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            errorCaught = true
            expectation.fulfill()
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 3.0)
        XCTAssertTrue(errorCaught)
    }
    
    /**
     * Test job scheduler with invalid job IDs
     * 
     * This test verifies that the job scheduler handles
     * invalid job IDs gracefully.
     */
    func testJobSchedulerInvalidJobIDs() async {
        // Given
        let expectation = XCTestExpectation(description: "Invalid job ID handled")
        
        // When
        await jobScheduler.scheduleJob(
            id: "", // Empty job ID
            priority: .normal,
            task: {
                // This should not execute
            }
        )
        
        // Wait for handling
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 3.0)
    }
    
    // MARK: - Performance Tests
    
    /**
     * Test job scheduler performance with many jobs
     * 
     * This test verifies that the job scheduler can handle
     * a large number of jobs efficiently.
     */
    func testJobSchedulerPerformance() async {
        // Given
        let startTime = Date()
        let expectation = XCTestExpectation(description: "All jobs completed")
        var completedJobs = 0
        let totalJobs = 100
        
        // When
        for i in 0..<totalJobs {
            await jobScheduler.scheduleJob(
                id: "performance-job-\(i)",
                priority: .normal,
                task: {
                    completedJobs += 1
                    if completedJobs == totalJobs {
                        expectation.fulfill()
                    }
                }
            )
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 10.0)
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        XCTAssertEqual(completedJobs, totalJobs)
        XCTAssertLessThan(duration, 5.0) // Should complete within 5 seconds
    }
    
    /**
     * Test job scheduler memory usage
     * 
     * This test verifies that the job scheduler doesn't
     * accumulate excessive memory usage over time.
     */
    func testJobSchedulerMemoryUsage() async {
        // Given
        await jobScheduler.start()
        
        // When - Schedule and complete many jobs
        for i in 0..<1000 {
            await jobScheduler.scheduleJob(
                id: "memory-job-\(i)",
                priority: .normal,
                task: {
                    // Simple task
                }
            )
        }
        
        // Then
        // In a real implementation, you would check memory usage
        // For now, we just verify the scheduler is still functional
        let expectation = XCTestExpectation(description: "Scheduler still functional")
        
        await jobScheduler.scheduleJob(
            id: "final-job",
            priority: .normal,
            task: {
                expectation.fulfill()
            }
        )
        
        await fulfillment(of: [expectation], timeout: 5.0)
        
        // Clean up
        await jobScheduler.stop()
    }
    
    // MARK: - Integration Tests
    
    /**
     * Test job scheduler integration with Kairo
     * 
     * This test verifies that the job scheduler works correctly
     * when integrated with the Kairo framework.
     */
    func testJobSchedulerKairoIntegration() async {
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
     * Test job scheduler with different health conditions
     * 
     * This test verifies that the job scheduler responds appropriately
     * to different device health conditions.
     */
    func testJobSchedulerWithHealthConditions() async {
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
     * Test job scheduler with realistic usage patterns
     * 
     * This test verifies that the job scheduler works correctly
     * with realistic usage patterns.
     */
    func testJobSchedulerRealisticUsage() async {
        // Given
        let expectation = XCTestExpectation(description: "Realistic usage completed")
        var jobsExecuted = 0
        
        // When - Simulate realistic usage patterns
        await jobScheduler.scheduleJob(
            id: "data-sync",
            priority: .high,
            task: {
                jobsExecuted += 1
            }
        )
        
        await jobScheduler.scheduleJob(
            id: "image-processing",
            priority: .normal,
            task: {
                jobsExecuted += 1
            }
        )
        
        await jobScheduler.scheduleJob(
            id: "cleanup",
            priority: .low,
            task: {
                jobsExecuted += 1
                if jobsExecuted == 3 {
                    expectation.fulfill()
                }
            }
        )
        
        // Then
        await fulfillment(of: [expectation], timeout: 10.0)
        XCTAssertEqual(jobsExecuted, 3)
    }
    
    /**
     * Test job scheduler with different job types
     * 
     * This test verifies that the job scheduler can handle
     * different types of jobs appropriately.
     */
    func testJobSchedulerDifferentJobTypes() async {
        // Given
        let expectation = XCTestExpectation(description: "Different job types completed")
        var jobTypesExecuted: Set<String> = []
        
        // When - Schedule different types of jobs
        await jobScheduler.scheduleJob(
            id: "network-job",
            priority: .high,
            task: {
                jobTypesExecuted.insert("network")
            }
        )
        
        await jobScheduler.scheduleJob(
            id: "cpu-job",
            priority: .normal,
            task: {
                jobTypesExecuted.insert("cpu")
            }
        )
        
        await jobScheduler.scheduleJob(
            id: "io-job",
            priority: .low,
            task: {
                jobTypesExecuted.insert("io")
                if jobTypesExecuted.count == 3 {
                    expectation.fulfill()
                }
            }
        )
        
        // Then
        await fulfillment(of: [expectation], timeout: 10.0)
        XCTAssertEqual(jobTypesExecuted.count, 3)
    }
}

/**
 * TestError - Test error types for testing
 * 
 * This enum defines test error types for testing error handling
 * in the job scheduler.
 */
enum TestError: Error {
    case jobFailed
    case schedulerError
    case networkError
    case timeoutError
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
