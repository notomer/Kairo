import Foundation

/**
 * RunTests - Main entry point for running Kairo tests
 * 
 * This demonstrates how to run all Kairo tests and provides
 * a comprehensive test suite for the entire framework.
 */

/**
 * Main function to run all Kairo tests
 * 
 * This function demonstrates how to run all Kairo tests
 * and provides a comprehensive test suite for the entire framework.
 */
@main
struct RunTests {
    static func main() async {
        print("🚀 Kairo Test Suite")
        print("=" * 50)
        print("Running comprehensive tests for the Kairo framework...")
        print()
        
        // Create test runner
        let testRunner = KairoTestRunner()
        
        // Run all tests
        let results = await testRunner.runAllTests()
        
        // Print final summary
        let summary = testRunner.getTestSummary()
        print("\n🎯 Final Summary")
        print("=" * 50)
        print("Total Test Cases: \(summary.totalTestCases)")
        print("Total Tests: \(summary.totalTests)")
        print("✅ Successful: \(summary.totalSuccesses)")
        print("❌ Failed: \(summary.totalFailures)")
        print("⏱️  Total Duration: \(String(format: "%.2f", summary.totalDuration))s")
        print("📈 Success Rate: \(String(format: "%.1f", summary.successRate))%")
        
        if summary.totalFailures == 0 {
            print("\n🎉 All tests passed! Kairo is ready for production.")
        } else {
            print("\n⚠️  Some tests failed. Please review the results above.")
        }
        
        print("\n" + "=" * 50)
        print("Test execution completed.")
    }
}

/**
 * Extension to String for repeating characters
 * 
 * This provides a convenient way to repeat characters
 * for formatting test output.
 */
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}
