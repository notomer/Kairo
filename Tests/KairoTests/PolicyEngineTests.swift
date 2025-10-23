import XCTest
import Foundation
@testable import Kairo

/**
 * PolicyEngineTests - Comprehensive test suite for PolicyEngine
 * 
 * This test suite covers all aspects of the PolicyEngine class including:
 * - Policy evaluation based on health conditions
 * - Health level determination
 * - Operation filtering and decision making
 * - Policy generation for different health levels
 * - Edge cases and error handling
 * - Performance under various conditions
 */
class PolicyEngineTests: XCTestCase {
    
    // MARK: - Properties
    
    /// Mock logger for testing
    private var mockLogger: MockLogger!
    
    /// Policy engine instance for testing
    private var policyEngine: PolicyEngine!
    
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
        policyEngine = PolicyEngine(config: testConfig, logger: mockLogger)
    }
    
    override func tearDown() async throws {
        policyEngine = nil
        testConfig = nil
        mockLogger = nil
        try await super.tearDown()
    }
    
    // MARK: - Policy Evaluation Tests
    
    /**
     * Test policy evaluation with excellent health conditions
     * 
     * This test verifies that the policy engine generates high-performance
     * policies when device health is excellent.
     */
    func testPolicyEvaluationExcellentHealth() {
        // Given - Excellent health conditions
        let excellentHealth = HealthSnapshot(
            batteryLevel: 0.95,
            lowPowerMode: false,
            thermalState: .nominal,
            networkReachability: .satisfied,
            networkConstrained: false,
            networkExpensive: false
        )
        
        // When
        let policy = policyEngine.evaluatePolicy(for: excellentHealth)
        
        // Then
        XCTAssertEqual(policy.healthLevel, .high)
        XCTAssertEqual(policy.maxNetworkConcurrent, testConfig.networkMaxConcurrent)
        XCTAssertTrue(policy.allowBackgroundMl)
        XCTAssertEqual(policy.imageVariant, .original)
        XCTAssertFalse(policy.preferCacheWhenUnhealthy)
    }
    
    /**
     * Test policy evaluation with poor health conditions
     * 
     * This test verifies that the policy engine generates conservative
     * policies when device health is poor.
     */
    func testPolicyEvaluationPoorHealth() {
        // Given - Poor health conditions
        let poorHealth = HealthSnapshot(
            batteryLevel: 0.20,
            lowPowerMode: true,
            thermalState: .serious,
            networkReachability: .satisfied,
            networkConstrained: true,
            networkExpensive: true
        )
        
        // When
        let policy = policyEngine.evaluatePolicy(for: poorHealth)
        
        // Then
        XCTAssertEqual(policy.healthLevel, .low)
        XCTAssertLessThan(policy.maxNetworkConcurrent, testConfig.networkMaxConcurrent)
        XCTAssertFalse(policy.allowBackgroundMl)
        XCTAssertEqual(policy.imageVariant, .medium)
        XCTAssertTrue(policy.preferCacheWhenUnhealthy)
    }
    
    /**
     * Test policy evaluation with critical health conditions
     * 
     * This test verifies that the policy engine generates very conservative
     * policies when device health is critical.
     */
    func testPolicyEvaluationCriticalHealth() {
        // Given - Critical health conditions
        let criticalHealth = HealthSnapshot(
            batteryLevel: 0.05,
            lowPowerMode: true,
            thermalState: .critical,
            networkReachability: .requiresConnection,
            networkConstrained: true,
            networkExpensive: true
        )
        
        // When
        let policy = policyEngine.evaluatePolicy(for: criticalHealth)
        
        // Then
        XCTAssertEqual(policy.healthLevel, .critical)
        XCTAssertEqual(policy.maxNetworkConcurrent, 1)
        XCTAssertFalse(policy.allowBackgroundMl)
        XCTAssertEqual(policy.imageVariant, .small)
        XCTAssertTrue(policy.preferCacheWhenUnhealthy)
    }
    
    /**
     * Test policy evaluation with medium health conditions
     * 
     * This test verifies that the policy engine generates balanced
     * policies when device health is medium.
     */
    func testPolicyEvaluationMediumHealth() {
        // Given - Medium health conditions
        let mediumHealth = HealthSnapshot(
            batteryLevel: 0.60,
            lowPowerMode: false,
            thermalState: .fair,
            networkReachability: .satisfied,
            networkConstrained: false,
            networkExpensive: false
        )
        
        // When
        let policy = policyEngine.evaluatePolicy(for: mediumHealth)
        
        // Then
        XCTAssertEqual(policy.healthLevel, .medium)
        XCTAssertLessThan(policy.maxNetworkConcurrent, testConfig.networkMaxConcurrent)
        XCTAssertTrue(policy.allowBackgroundMl)
        XCTAssertEqual(policy.imageVariant, .large)
        XCTAssertFalse(policy.preferCacheWhenUnhealthy)
    }
    
    // MARK: - Operation Filtering Tests
    
    /**
     * Test operation filtering with excellent health
     * 
     * This test verifies that most operations are allowed when
     * device health is excellent.
     */
    func testOperationFilteringExcellentHealth() {
        // Given - Excellent health
        let excellentHealth = HealthSnapshot(
            batteryLevel: 0.95,
            lowPowerMode: false,
            thermalState: .nominal,
            networkReachability: .satisfied,
            networkConstrained: false,
            networkExpensive: false
        )
        
        let policy = Policy(
            maxNetworkConcurrent: 6,
            allowBackgroundMl: true,
            imageVariant: .original,
            preferCacheWhenUnhealthy: false,
            healthLevel: .high
        )
        
        // When & Then
        XCTAssertTrue(policyEngine.shouldAllowOperation(.networkRequest(priority: .normal), given: excellentHealth, currentPolicy: policy))
        XCTAssertTrue(policyEngine.shouldAllowOperation(.imageProcessing(size: .large), given: excellentHealth, currentPolicy: policy))
        XCTAssertTrue(policyEngine.shouldAllowOperation(.machineLearningInference, given: excellentHealth, currentPolicy: policy))
        XCTAssertTrue(policyEngine.shouldAllowOperation(.backgroundTask, given: excellentHealth, currentPolicy: policy))
    }
    
    /**
     * Test operation filtering with poor health
     * 
     * This test verifies that many operations are blocked when
     * device health is poor.
     */
    func testOperationFilteringPoorHealth() {
        // Given - Poor health
        let poorHealth = HealthSnapshot(
            batteryLevel: 0.20,
            lowPowerMode: true,
            thermalState: .serious,
            networkReachability: .satisfied,
            networkConstrained: true,
            networkExpensive: true
        )
        
        let policy = Policy(
            maxNetworkConcurrent: 2,
            allowBackgroundMl: false,
            imageVariant: .medium,
            preferCacheWhenUnhealthy: true,
            healthLevel: .low
        )
        
        // When & Then
        XCTAssertFalse(policyEngine.shouldAllowOperation(.machineLearningInference, given: poorHealth, currentPolicy: policy))
        XCTAssertFalse(policyEngine.shouldAllowOperation(.videoProcessing, given: poorHealth, currentPolicy: policy))
        XCTAssertFalse(policyEngine.shouldAllowOperation(.fileDownload(size: 100_000_000), given: poorHealth, currentPolicy: policy))
    }
    
    /**
     * Test operation filtering with critical health
     * 
     * This test verifies that most operations are blocked when
     * device health is critical.
     */
    func testOperationFilteringCriticalHealth() {
        // Given - Critical health
        let criticalHealth = HealthSnapshot(
            batteryLevel: 0.05,
            lowPowerMode: true,
            thermalState: .critical,
            networkReachability: .requiresConnection,
            networkConstrained: true,
            networkExpensive: true
        )
        
        let policy = Policy(
            maxNetworkConcurrent: 1,
            allowBackgroundMl: false,
            imageVariant: .small,
            preferCacheWhenUnhealthy: true,
            healthLevel: .critical
        )
        
        // When & Then
        XCTAssertFalse(policyEngine.shouldAllowOperation(.machineLearningInference, given: criticalHealth, currentPolicy: policy))
        XCTAssertFalse(policyEngine.shouldAllowOperation(.videoProcessing, given: criticalHealth, currentPolicy: policy))
        XCTAssertFalse(policyEngine.shouldAllowOperation(.backgroundTask, given: criticalHealth, currentPolicy: policy))
    }
    
    /**
     * Test operation filtering with thermal constraints
     * 
     * This test verifies that CPU-intensive operations are blocked
     * when thermal state is serious or critical.
     */
    func testOperationFilteringThermalConstraints() {
        // Given - Serious thermal state
        let seriousThermalHealth = HealthSnapshot(
            batteryLevel: 0.80,
            lowPowerMode: false,
            thermalState: .serious,
            networkReachability: .satisfied,
            networkConstrained: false,
            networkExpensive: false
        )
        
        let policy = Policy(
            maxNetworkConcurrent: 6,
            allowBackgroundMl: true,
            imageVariant: .original,
            preferCacheWhenUnhealthy: false,
            healthLevel: .high
        )
        
        // When & Then
        XCTAssertFalse(policyEngine.shouldAllowOperation(.machineLearningInference, given: seriousThermalHealth, currentPolicy: policy))
        XCTAssertFalse(policyEngine.shouldAllowOperation(.videoProcessing, given: seriousThermalHealth, currentPolicy: policy))
        XCTAssertTrue(policyEngine.shouldAllowOperation(.networkRequest(priority: .normal), given: seriousThermalHealth, currentPolicy: policy))
    }
    
    /**
     * Test operation filtering with critical thermal state
     * 
     * This test verifies that only critical operations are allowed
     * when thermal state is critical.
     */
    func testOperationFilteringCriticalThermal() {
        // Given - Critical thermal state
        let criticalThermalHealth = HealthSnapshot(
            batteryLevel: 0.80,
            lowPowerMode: false,
            thermalState: .critical,
            networkReachability: .satisfied,
            networkConstrained: false,
            networkExpensive: false
        )
        
        let policy = Policy(
            maxNetworkConcurrent: 6,
            allowBackgroundMl: true,
            imageVariant: .original,
            preferCacheWhenUnhealthy: false,
            healthLevel: .high
        )
        
        // When & Then
        XCTAssertFalse(policyEngine.shouldAllowOperation(.machineLearningInference, given: criticalThermalHealth, currentPolicy: policy))
        XCTAssertFalse(policyEngine.shouldAllowOperation(.videoProcessing, given: criticalThermalHealth, currentPolicy: policy))
        XCTAssertFalse(policyEngine.shouldAllowOperation(.networkRequest(priority: .normal), given: criticalThermalHealth, currentPolicy: policy))
        XCTAssertTrue(policyEngine.shouldAllowOperation(.networkRequest(priority: .critical), given: criticalThermalHealth, currentPolicy: policy))
    }
    
    /**
     * Test operation filtering with low battery
     * 
     * This test verifies that expensive operations are blocked
     * when battery level is low.
     */
    func testOperationFilteringLowBattery() {
        // Given - Low battery
        let lowBatteryHealth = HealthSnapshot(
            batteryLevel: 0.10, // 10% battery
            lowPowerMode: false,
            thermalState: .nominal,
            networkReachability: .satisfied,
            networkConstrained: false,
            networkExpensive: false
        )
        
        let policy = Policy(
            maxNetworkConcurrent: 6,
            allowBackgroundMl: true,
            imageVariant: .original,
            preferCacheWhenUnhealthy: false,
            healthLevel: .high
        )
        
        // When & Then
        XCTAssertFalse(policyEngine.shouldAllowOperation(.machineLearningInference, given: lowBatteryHealth, currentPolicy: policy))
        XCTAssertFalse(policyEngine.shouldAllowOperation(.videoProcessing, given: lowBatteryHealth, currentPolicy: policy))
        XCTAssertFalse(policyEngine.shouldAllowOperation(.fileDownload(size: 100_000_000), given: lowBatteryHealth, currentPolicy: policy))
        XCTAssertTrue(policyEngine.shouldAllowOperation(.networkRequest(priority: .normal), given: lowBatteryHealth, currentPolicy: policy))
    }
    
    /**
     * Test operation filtering with network constraints
     * 
     * This test verifies that network-intensive operations are blocked
     * when network is constrained or expensive.
     */
    func testOperationFilteringNetworkConstraints() {
        // Given - Constrained network
        let constrainedNetworkHealth = HealthSnapshot(
            batteryLevel: 0.80,
            lowPowerMode: false,
            thermalState: .nominal,
            networkReachability: .satisfied,
            networkConstrained: true,
            networkExpensive: true
        )
        
        let policy = Policy(
            maxNetworkConcurrent: 6,
            allowBackgroundMl: true,
            imageVariant: .original,
            preferCacheWhenUnhealthy: false,
            healthLevel: .high
        )
        
        // When & Then
        XCTAssertFalse(policyEngine.shouldAllowOperation(.fileDownload(size: 100_000_000), given: constrainedNetworkHealth, currentPolicy: policy))
        XCTAssertFalse(policyEngine.shouldAllowOperation(.imageProcessing(size: .large), given: constrainedNetworkHealth, currentPolicy: policy))
        XCTAssertTrue(policyEngine.shouldAllowOperation(.networkRequest(priority: .normal), given: constrainedNetworkHealth, currentPolicy: policy))
    }
    
    // MARK: - Edge Cases and Error Handling
    
    /**
     * Test policy evaluation with invalid health data
     * 
     * This test verifies that the policy engine handles
     * invalid health data gracefully.
     */
    func testPolicyEvaluationInvalidData() {
        // Given - Invalid health data
        let invalidHealth = HealthSnapshot(
            batteryLevel: -1.0, // Invalid negative battery
            lowPowerMode: false,
            thermalState: .nominal,
            networkReachability: .satisfied,
            networkConstrained: false,
            networkExpensive: false
        )
        
        // When
        let policy = policyEngine.evaluatePolicy(for: invalidHealth)
        
        // Then
        // Should still generate a policy, but it should be conservative
        XCTAssertNotNil(policy)
        XCTAssertLessThan(policy.maxNetworkConcurrent, testConfig.networkMaxConcurrent)
    }
    
    /**
     * Test policy evaluation with extreme values
     * 
     * This test verifies that the policy engine handles
     * extreme values gracefully.
     */
    func testPolicyEvaluationExtremeValues() {
        // Given - Extreme values
        let extremeHealth = HealthSnapshot(
            batteryLevel: 2.0, // Over 100% battery
            lowPowerMode: false,
            thermalState: .nominal,
            networkReachability: .satisfied,
            networkConstrained: false,
            networkExpensive: false
        )
        
        // When
        let policy = policyEngine.evaluatePolicy(for: extremeHealth)
        
        // Then
        // Should still generate a policy
        XCTAssertNotNil(policy)
        XCTAssertLessThanOrEqual(policy.maxNetworkConcurrent, testConfig.networkMaxConcurrent)
    }
    
    /**
     * Test operation filtering with unknown operation types
     * 
     * This test verifies that the policy engine handles
     * unknown operation types gracefully.
     */
    func testOperationFilteringUnknownOperation() {
        // Given - Good health
        let goodHealth = HealthSnapshot(
            batteryLevel: 0.80,
            lowPowerMode: false,
            thermalState: .nominal,
            networkReachability: .satisfied,
            networkConstrained: false,
            networkExpensive: false
        )
        
        let policy = Policy(
            maxNetworkConcurrent: 6,
            allowBackgroundMl: true,
            imageVariant: .original,
            preferCacheWhenUnhealthy: false,
            healthLevel: .high
        )
        
        // When & Then
        // Unknown operations should be allowed by default
        XCTAssertTrue(policyEngine.shouldAllowOperation(.backgroundTask, given: goodHealth, currentPolicy: policy))
    }
    
    // MARK: - Performance Tests
    
    /**
     * Test policy evaluation performance
     * 
     * This test verifies that policy evaluation is fast
     * and doesn't cause performance issues.
     */
    func testPolicyEvaluationPerformance() {
        // Given - Health snapshot
        let health = HealthSnapshot(
            batteryLevel: 0.80,
            lowPowerMode: false,
            thermalState: .nominal,
            networkReachability: .satisfied,
            networkConstrained: false,
            networkExpensive: false
        )
        
        // When - Measure evaluation time
        let startTime = Date()
        for _ in 0..<1000 {
            let _ = policyEngine.evaluatePolicy(for: health)
        }
        let endTime = Date()
        
        // Then
        let duration = endTime.timeIntervalSince(startTime)
        XCTAssertLessThan(duration, 1.0) // Should complete within 1 second
    }
    
    /**
     * Test operation filtering performance
     * 
     * This test verifies that operation filtering is fast
     * and doesn't cause performance issues.
     */
    func testOperationFilteringPerformance() {
        // Given - Health snapshot and policy
        let health = HealthSnapshot(
            batteryLevel: 0.80,
            lowPowerMode: false,
            thermalState: .nominal,
            networkReachability: .satisfied,
            networkConstrained: false,
            networkExpensive: false
        )
        
        let policy = Policy(
            maxNetworkConcurrent: 6,
            allowBackgroundMl: true,
            imageVariant: .original,
            preferCacheWhenUnhealthy: false,
            healthLevel: .high
        )
        
        // When - Measure filtering time
        let startTime = Date()
        for _ in 0..<1000 {
            let _ = policyEngine.shouldAllowOperation(.networkRequest(priority: .normal), given: health, currentPolicy: policy)
        }
        let endTime = Date()
        
        // Then
        let duration = endTime.timeIntervalSince(startTime)
        XCTAssertLessThan(duration, 1.0) // Should complete within 1 second
    }
    
    // MARK: - Integration Tests
    
    /**
     * Test policy engine with real-world scenarios
     * 
     * This test verifies that the policy engine works correctly
     * with realistic health scenarios.
     */
    func testRealWorldScenarios() {
        // Scenario 1: User with good battery, WiFi, normal usage
        let goodScenario = HealthSnapshot(
            batteryLevel: 0.85,
            lowPowerMode: false,
            thermalState: .nominal,
            networkReachability: .satisfied,
            networkConstrained: false,
            networkExpensive: false
        )
        
        let goodPolicy = policyEngine.evaluatePolicy(for: goodScenario)
        XCTAssertEqual(goodPolicy.healthLevel, .high)
        XCTAssertTrue(goodPolicy.allowBackgroundMl)
        
        // Scenario 2: User with low battery, cellular data, heavy usage
        let poorScenario = HealthSnapshot(
            batteryLevel: 0.25,
            lowPowerMode: true,
            thermalState: .fair,
            networkReachability: .satisfied,
            networkConstrained: true,
            networkExpensive: true
        )
        
        let poorPolicy = policyEngine.evaluatePolicy(for: poorScenario)
        XCTAssertEqual(poorPolicy.healthLevel, .low)
        XCTAssertFalse(poorPolicy.allowBackgroundMl)
        
        // Scenario 3: User with critical battery, no network, overheating
        let criticalScenario = HealthSnapshot(
            batteryLevel: 0.03,
            lowPowerMode: true,
            thermalState: .critical,
            networkReachability: .requiresConnection,
            networkConstrained: true,
            networkExpensive: true
        )
        
        let criticalPolicy = policyEngine.evaluatePolicy(for: criticalScenario)
        XCTAssertEqual(criticalPolicy.healthLevel, .critical)
        XCTAssertEqual(criticalPolicy.maxNetworkConcurrent, 1)
    }
    
    /**
     * Test policy engine with gradual health degradation
     * 
     * This test verifies that the policy engine responds appropriately
     * to gradual health degradation.
     */
    func testGradualHealthDegradation() {
        // Start with excellent health
        var health = HealthSnapshot(
            batteryLevel: 0.95,
            lowPowerMode: false,
            thermalState: .nominal,
            networkReachability: .satisfied,
            networkConstrained: false,
            networkExpensive: false
        )
        
        var policy = policyEngine.evaluatePolicy(for: health)
        XCTAssertEqual(policy.healthLevel, .high)
        
        // Gradually degrade battery
        health = HealthSnapshot(
            batteryLevel: 0.60,
            lowPowerMode: false,
            thermalState: .nominal,
            networkReachability: .satisfied,
            networkConstrained: false,
            networkExpensive: false
        )
        
        policy = policyEngine.evaluatePolicy(for: health)
        XCTAssertEqual(policy.healthLevel, .medium)
        
        // Further degrade with thermal issues
        health = HealthSnapshot(
            batteryLevel: 0.30,
            lowPowerMode: true,
            thermalState: .serious,
            networkReachability: .satisfied,
            networkConstrained: true,
            networkExpensive: false
        )
        
        policy = policyEngine.evaluatePolicy(for: health)
        XCTAssertEqual(policy.healthLevel, .low)
        
        // Critical state
        health = HealthSnapshot(
            batteryLevel: 0.05,
            lowPowerMode: true,
            thermalState: .critical,
            networkReachability: .requiresConnection,
            networkConstrained: true,
            networkExpensive: true
        )
        
        policy = policyEngine.evaluatePolicy(for: health)
        XCTAssertEqual(policy.healthLevel, .critical)
    }
}
