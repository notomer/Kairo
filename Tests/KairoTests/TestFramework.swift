import Foundation

/**
 * SimpleTestFramework - A lightweight testing framework for Kairo
 * 
 * This provides basic testing functionality without external dependencies.
 * It's designed to be simple and self-contained for the Kairo project.
 */

/**
 * TestCase - Base class for all test cases
 * 
 * This provides basic testing functionality including assertions,
 * expectations, and test lifecycle management.
 */
open class TestCase {
    
    // MARK: - Properties
    
    /// Test name for identification
    public let testName: String
    
    /// Test start time
    private var startTime: Date?
    
    /// Test results
    private var results: [TestResult] = []
    
    // MARK: - Initialization
    
    /**
     * Initialize a test case
     * 
     * - Parameter testName: Name of the test case
     */
    public init(testName: String) {
        self.testName = testName
    }
    
    // MARK: - Test Lifecycle
    
    /**
     * Set up test environment
     * 
     * Override this method to set up test-specific resources.
     */
    open func setUp() async throws {
        // Override in subclasses
    }
    
    /**
     * Tear down test environment
     * 
     * Override this method to clean up test-specific resources.
     */
    open func tearDown() async throws {
        // Override in subclasses
    }
    
    /**
     * Run the test case
     * 
     * This method runs the test case and returns the results.
     * 
     * - Returns: Test results
     */
    public func run() async -> TestResults {
        startTime = Date()
        results.removeAll()
        
        do {
            try await setUp()
            try await runTests()
            try await tearDown()
        } catch {
            addResult(TestResult(
                testName: testName,
                success: false,
                error: error,
                duration: Date().timeIntervalSince(startTime ?? Date())
            ))
        }
        
        return TestResults(
            testName: testName,
            results: results,
            totalDuration: Date().timeIntervalSince(startTime ?? Date())
        )
    }
    
    /**
     * Run individual tests
     * 
     * Override this method to implement test logic.
     */
    open func runTests() async throws {
        // Override in subclasses
    }
    
    // MARK: - Assertions
    
    /**
     * Assert that a condition is true
     * 
     * - Parameters:
     *   - condition: The condition to test
     *   - message: Optional message to include in failure
     * - Throws: TestError if assertion fails
     */
    public func assertTrue(_ condition: Bool, _ message: String = "") throws {
        if !condition {
            throw TestError.assertionFailed("Assertion failed: \(message)")
        }
    }
    
    /**
     * Assert that a condition is false
     * 
     * - Parameters:
     *   - condition: The condition to test
     *   - message: Optional message to include in failure
     * - Throws: TestError if assertion fails
     */
    public func assertFalse(_ condition: Bool, _ message: String = "") throws {
        if condition {
            throw TestError.assertionFailed("Assertion failed: \(message)")
        }
    }
    
    /**
     * Assert that two values are equal
     * 
     * - Parameters:
     *   - expected: The expected value
     *   - actual: The actual value
     *   - message: Optional message to include in failure
     * - Throws: TestError if assertion fails
     */
    public func assertEqual<T: Equatable>(_ expected: T, _ actual: T, _ message: String = "") throws {
        if expected != actual {
            throw TestError.assertionFailed("Expected \(expected), got \(actual). \(message)")
        }
    }
    
    /**
     * Assert that two values are not equal
     * 
     * - Parameters:
     *   - expected: The expected value
     *   - actual: The actual value
     *   - message: Optional message to include in failure
     * - Throws: TestError if assertion fails
     */
    public func assertNotEqual<T: Equatable>(_ expected: T, _ actual: T, _ message: String = "") throws {
        if expected == actual {
            throw TestError.assertionFailed("Expected values to be different. \(message)")
        }
    }
    
    /**
     * Assert that a value is not nil
     * 
     * - Parameters:
     *   - value: The value to test
     *   - message: Optional message to include in failure
     * - Throws: TestError if assertion fails
     */
    public func assertNotNil<T>(_ value: T?, _ message: String = "") throws {
        if value == nil {
            throw TestError.assertionFailed("Expected non-nil value. \(message)")
        }
    }
    
    /**
     * Assert that a value is nil
     * 
     * - Parameters:
     *   - value: The value to test
     *   - message: Optional message to include in failure
     * - Throws: TestError if assertion fails
     */
    public func assertNil<T>(_ value: T?, _ message: String = "") throws {
        if value != nil {
            throw TestError.assertionFailed("Expected nil value. \(message)")
        }
    }
    
    /**
     * Assert that a value is greater than another
     * 
     * - Parameters:
     *   - value: The value to test
     *   - other: The value to compare against
     *   - message: Optional message to include in failure
     * - Throws: TestError if assertion fails
     */
    public func assertGreaterThan<T: Comparable>(_ value: T, _ other: T, _ message: String = "") throws {
        if value <= other {
            throw TestError.assertionFailed("Expected \(value) > \(other). \(message)")
        }
    }
    
    /**
     * Assert that a value is less than another
     * 
     * - Parameters:
     *   - value: The value to test
     *   - other: The value to compare against
     *   - message: Optional message to include in failure
     * - Throws: TestError if assertion fails
     */
    public func assertLessThan<T: Comparable>(_ value: T, _ other: T, _ message: String = "") throws {
        if value >= other {
            throw TestError.assertionFailed("Expected \(value) < \(other). \(message)")
        }
    }
    
    /**
     * Assert that a value is greater than or equal to another
     * 
     * - Parameters:
     *   - value: The value to test
     *   - other: The value to compare against
     *   - message: Optional message to include in failure
     * - Throws: TestError if assertion fails
     */
    public func assertGreaterThanOrEqual<T: Comparable>(_ value: T, _ other: T, _ message: String = "") throws {
        if value < other {
            throw TestError.assertionFailed("Expected \(value) >= \(other). \(message)")
        }
    }
    
    /**
     * Assert that a value is less than or equal to another
     * 
     * - Parameters:
     *   - value: The value to test
     *   - other: The value to compare against
     *   - message: Optional message to include in failure
     * - Throws: TestError if assertion fails
     */
    public func assertLessThanOrEqual<T: Comparable>(_ value: T, _ other: T, _ message: String = "") throws {
        if value > other {
            throw TestError.assertionFailed("Expected \(value) <= \(other). \(message)")
        }
    }
    
    // MARK: - Expectations
    
    /**
     * Create an expectation for async testing
     * 
     * - Parameter description: Description of the expectation
     * - Returns: A new expectation
     */
    public func expectation(description: String) -> TestExpectation {
        return TestExpectation(description: description)
    }
    
    /**
     * Wait for expectations to be fulfilled
     * 
     * - Parameters:
     *   - expectations: Array of expectations to wait for
     *   - timeout: Maximum time to wait in seconds
     * - Throws: TestError if timeout is exceeded
     */
    public func waitForExpectations(_ expectations: [TestExpectation], timeout: TimeInterval = 5.0) async throws {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            if expectations.allSatisfy({ $0.isFulfilled }) {
                return
            }
            
            try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        }
        
        throw TestError.timeout("Expectations not fulfilled within timeout")
    }
    
    // MARK: - Test Results
    
    /**
     * Add a test result
     * 
     * - Parameter result: The test result to add
     */
    public func addResult(_ result: TestResult) {
        results.append(result)
    }
    
    /**
     * Add a successful test result
     * 
     * - Parameters:
     *   - testName: Name of the test
     *   - duration: Duration of the test
     */
    public func addSuccess(_ testName: String, duration: TimeInterval = 0.0) {
        addResult(TestResult(
            testName: testName,
            success: true,
            error: nil,
            duration: duration
        ))
    }
    
    /**
     * Add a failed test result
     * 
     * - Parameters:
     *   - testName: Name of the test
     *   - error: Error that caused the failure
     *   - duration: Duration of the test
     */
    public func addFailure(_ testName: String, error: Error, duration: TimeInterval = 0.0) {
        addResult(TestResult(
            testName: testName,
            success: false,
            error: error,
            duration: duration
        ))
    }
}

/**
 * TestExpectation - Represents an expectation for async testing
 * 
 * This allows tests to wait for specific conditions to be met.
 */
public class TestExpectation {
    
    // MARK: - Properties
    
    /// Description of the expectation
    public let description: String
    
    /// Whether the expectation has been fulfilled
    public private(set) var isFulfilled: Bool = false
    
    /// Time when the expectation was fulfilled
    public private(set) var fulfillmentTime: Date?
    
    // MARK: - Initialization
    
    /**
     * Initialize an expectation
     * 
     * - Parameter description: Description of the expectation
     */
    public init(description: String) {
        self.description = description
    }
    
    // MARK: - Public Methods
    
    /**
     * Fulfill the expectation
     * 
     * This method should be called when the expected condition is met.
     */
    public func fulfill() {
        isFulfilled = true
        fulfillmentTime = Date()
    }
}

/**
 * TestResult - Represents the result of a single test
 * 
 * This contains information about whether a test passed or failed,
 * along with any error information and timing data.
 */
public struct TestResult {
    /// Name of the test
    public let testName: String
    
    /// Whether the test was successful
    public let success: Bool
    
    /// Error that caused failure (if any)
    public let error: Error?
    
    /// Duration of the test in seconds
    public let duration: TimeInterval
    
    /**
     * Initialize a test result
     * 
     * - Parameters:
     *   - testName: Name of the test
     *   - success: Whether the test was successful
     *   - error: Error that caused failure (if any)
     *   - duration: Duration of the test in seconds
     */
    public init(testName: String, success: Bool, error: Error?, duration: TimeInterval) {
        self.testName = testName
        self.success = success
        self.error = error
        self.duration = duration
    }
}

/**
 * TestResults - Represents the results of a test case
 * 
 * This contains information about all tests in a test case,
 * including overall success rate and timing data.
 */
public struct TestResults {
    /// Name of the test case
    public let testName: String
    
    /// Results of individual tests
    public let results: [TestResult]
    
    /// Total duration of the test case
    public let totalDuration: TimeInterval
    
    /// Number of successful tests
    public var successCount: Int {
        return results.filter { $0.success }.count
    }
    
    /// Number of failed tests
    public var failureCount: Int {
        return results.filter { !$0.success }.count
    }
    
    /// Total number of tests
    public var totalCount: Int {
        return results.count
    }
    
    /// Success rate as a percentage
    public var successRate: Double {
        guard totalCount > 0 else { return 0.0 }
        return Double(successCount) / Double(totalCount) * 100.0
    }
    
    /// Whether all tests passed
    public var allPassed: Bool {
        return failureCount == 0
    }
    
    /**
     * Initialize test results
     * 
     * - Parameters:
     *   - testName: Name of the test case
     *   - results: Results of individual tests
     *   - totalDuration: Total duration of the test case
     */
    public init(testName: String, results: [TestResult], totalDuration: TimeInterval) {
        self.testName = testName
        self.results = results
        self.totalDuration = totalDuration
    }
}

/**
 * TestError - Errors that can occur during testing
 * 
 * This enum defines all the possible errors that can occur
 * during test execution.
 */
public enum TestError: Error, LocalizedError {
    case assertionFailed(String)
    case timeout(String)
    case setupFailed(String)
    case teardownFailed(String)
    case unknown(String)
    
    /**
     * Get a human-readable description of this error
     */
    public var errorDescription: String? {
        switch self {
        case .assertionFailed(let message):
            return "Assertion failed: \(message)"
        case .timeout(let message):
            return "Timeout: \(message)"
        case .setupFailed(let message):
            return "Setup failed: \(message)"
        case .teardownFailed(let message):
            return "Teardown failed: \(message)"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}

/**
 * TestRunner - Runs test cases and collects results
 * 
 * This class provides functionality for running multiple
 * test cases and collecting their results.
 */
public class TestRunner {
    
    // MARK: - Properties
    
    /// Test cases to run
    private var testCases: [TestCase] = []
    
    /// Results of all test cases
    private var allResults: [TestResults] = []
    
    // MARK: - Public Methods
    
    /**
     * Add a test case to the runner
     * 
     * - Parameter testCase: The test case to add
     */
    public func addTestCase(_ testCase: TestCase) {
        testCases.append(testCase)
    }
    
    /**
     * Run all test cases
     * 
     * This method runs all added test cases and returns
     * the combined results.
     * 
     * - Returns: Combined results of all test cases
     */
    public func runAll() async -> [TestResults] {
        allResults.removeAll()
        
        for testCase in testCases {
            let results = await testCase.run()
            allResults.append(results)
        }
        
        return allResults
    }
    
    /**
     * Get summary of all test results
     * 
     * - Returns: Summary of all test results
     */
    public func getSummary() -> TestSummary {
        let totalTests = allResults.reduce(0) { $0 + $1.totalCount }
        let totalSuccesses = allResults.reduce(0) { $0 + $1.successCount }
        let totalFailures = allResults.reduce(0) { $0 + $1.failureCount }
        let totalDuration = allResults.reduce(0.0) { $0 + $1.totalDuration }
        
        return TestSummary(
            totalTestCases: allResults.count,
            totalTests: totalTests,
            totalSuccesses: totalSuccesses,
            totalFailures: totalFailures,
            totalDuration: totalDuration,
            successRate: totalTests > 0 ? Double(totalSuccesses) / Double(totalTests) * 100.0 : 0.0
        )
    }
}

/**
 * TestSummary - Summary of all test results
 * 
 * This contains aggregated information about all test results
 * including counts, timing, and success rates.
 */
public struct TestSummary {
    /// Total number of test cases
    public let totalTestCases: Int
    
    /// Total number of tests
    public let totalTests: Int
    
    /// Total number of successful tests
    public let totalSuccesses: Int
    
    /// Total number of failed tests
    public let totalFailures: Int
    
    /// Total duration of all tests
    public let totalDuration: TimeInterval
    
    /// Overall success rate as a percentage
    public let successRate: Double
    
    /**
     * Initialize test summary
     * 
     * - Parameters:
     *   - totalTestCases: Total number of test cases
     *   - totalTests: Total number of tests
     *   - totalSuccesses: Total number of successful tests
     *   - totalFailures: Total number of failed tests
     *   - totalDuration: Total duration of all tests
     *   - successRate: Overall success rate as a percentage
     */
    public init(totalTestCases: Int, totalTests: Int, totalSuccesses: Int, totalFailures: Int, totalDuration: TimeInterval, successRate: Double) {
        self.totalTestCases = totalTestCases
        self.totalTests = totalTests
        self.totalSuccesses = totalSuccesses
        self.totalFailures = totalFailures
        self.totalDuration = totalDuration
        self.successRate = successRate
    }
}
