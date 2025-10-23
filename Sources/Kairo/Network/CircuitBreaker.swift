import Foundation

/**
 * CircuitBreaker - A fault tolerance pattern for network operations
 * 
 * The Circuit Breaker pattern is like an electrical circuit breaker in your house.
 * When there are too many electrical problems, the breaker "trips" and cuts off
 * power to prevent damage. Similarly, when network operations fail too often,
 * the circuit breaker "opens" and stops making requests to prevent further damage.
 * 
 * Key states:
 * - CLOSED: Normal operation, requests are allowed
 * - OPEN: Too many failures, requests are blocked
 * - HALF_OPEN: Testing if the service has recovered
 */

/**
 * CircuitBreakerState - The current state of the circuit breaker
 * 
 * This enum represents the three possible states of a circuit breaker.
 * Each state has different behavior for handling requests.
 */
public enum CircuitBreakerState: Sendable {
    case closed    // Normal operation - requests are allowed
    case open      // Circuit is open - requests are blocked
    case halfOpen  // Testing if service has recovered
    
    /**
     * Get a human-readable description of the current state.
     */
    public var description: String {
        switch self {
        case .closed:
            return "Closed - Normal operation"
        case .open:
            return "Open - Blocking requests due to failures"
        case .halfOpen:
            return "Half-Open - Testing service recovery"
        }
    }
}

/**
 * CircuitBreakerConfiguration - Settings for circuit breaker behavior
 * 
 * This struct contains all the configuration options for a circuit breaker.
 * You can customize the failure thresholds, timeouts, and recovery behavior.
 */
public struct CircuitBreakerConfiguration: Sendable {
    /// Number of consecutive failures before opening the circuit
    public let failureThreshold: Int
    
    /// Time to wait before trying to close the circuit again (in seconds)
    public let timeoutSeconds: TimeInterval
    
    /// Number of successful requests needed in half-open state to close the circuit
    public let successThreshold: Int
    
    /// Maximum number of requests to allow in half-open state
    public let maxRequestsInHalfOpen: Int
    
    /**
     * Initialize circuit breaker configuration.
     * 
     * - Parameters:
     *   - failureThreshold: Failures needed to open circuit (default: 5)
     *   - timeoutSeconds: Time to wait before trying to close circuit (default: 60)
     *   - successThreshold: Successes needed to close circuit (default: 3)
     *   - maxRequestsInHalfOpen: Max requests in half-open state (default: 5)
     */
    public init(
        failureThreshold: Int = 5,
        timeoutSeconds: TimeInterval = 60.0,
        successThreshold: Int = 3,
        maxRequestsInHalfOpen: Int = 5
    ) {
        self.failureThreshold = failureThreshold
        self.timeoutSeconds = timeoutSeconds
        self.successThreshold = successThreshold
        self.maxRequestsInHalfOpen = maxRequestsInHalfOpen
    }
    
    /// Default configuration for most use cases
    public static let `default` = CircuitBreakerConfiguration()
}

/**
 * CircuitBreaker - Implements the circuit breaker pattern for fault tolerance
 * 
 * This class monitors the success/failure of operations and automatically
 * blocks requests when failure rates become too high. It helps prevent
 * cascading failures and gives failing services time to recover.
 */
public actor CircuitBreaker {
    
    // MARK: - Properties
    
    /// Current state of the circuit breaker
    private var state: CircuitBreakerState = .closed
    
    /// Configuration settings for the circuit breaker
    private let config: CircuitBreakerConfiguration
    
    /// Number of consecutive failures
    private var failureCount: Int = 0
    
    /// Number of consecutive successes (used in half-open state)
    private var successCount: Int = 0
    
    /// Number of requests made in half-open state
    private var requestsInHalfOpen: Int = 0
    
    /// Time when the circuit was last opened
    private var lastFailureTime: Date?
    
    /// Logger for debugging and monitoring
    private let logger: Logger
    
    /// Name identifier for this circuit breaker (useful when you have multiple)
    private let name: String
    
    // MARK: - Initialization
    
    /**
     * Initialize a circuit breaker with configuration.
     * 
     * - Parameters:
     *   - name: Name identifier for this circuit breaker
     *   - config: Configuration settings
     *   - logger: Logger instance for debugging
     * 
     * This creates a new circuit breaker that will monitor operations
     * and automatically open when failure rates become too high.
     */
    public init(name: String, config: CircuitBreakerConfiguration = .default, logger: Logger) {
        self.name = name
        self.config = config
        self.logger = logger
        
        logger.info("CircuitBreaker '\(name)' initialized with config: \(config)")
    }
    
    // MARK: - Public Methods
    
    /**
     * Execute an operation through the circuit breaker.
     * 
     * - Parameter operation: The async operation to execute
     * - Returns: The result of the operation
     * - Throws: KairoError.circuitOpen if the circuit is open, or the operation's error
     * 
     * This is the main method for using the circuit breaker. It will:
     * - Allow the operation if the circuit is closed
     * - Block the operation if the circuit is open
     * - Allow limited operations if the circuit is half-open
     * - Update the circuit state based on the operation's success/failure
     * 
     * Usage:
     * ```swift
     * do {
     *     let result = try await circuitBreaker.execute {
     *         try await networkRequest()
     *     }
     *     // Handle successful result
     * } catch KairoError.circuitOpen {
     *     // Circuit is open, service is down
     * } catch {
     *     // Other error occurred
     * }
     * ```
     */
    public func execute<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        // Check if we should allow this operation
        try await checkOperationAllowed()
        
        do {
            // Execute the operation
            let result = try await operation()
            
            // Record success
            await recordSuccess()
            
            logger.debug("CircuitBreaker '\(name)' operation succeeded")
            return result
            
        } catch {
            // Record failure
            await recordFailure()
            
            logger.debug("CircuitBreaker '\(name)' operation failed: \(error)")
            throw error
        }
    }
    
    /**
     * Get the current state of the circuit breaker.
     * 
     * - Returns: Current circuit breaker state
     * 
     * This is useful for monitoring and debugging circuit breaker behavior.
     */
    public func getState() -> CircuitBreakerState {
        return state
    }
    
    /**
     * Get detailed status information about the circuit breaker.
     * 
     * - Returns: Dictionary with current status information
     * 
     * This provides comprehensive information about the circuit breaker's
     * current state, failure counts, and timing information.
     */
    public func getStatus() -> [String: Any] {
        var status: [String: Any] = [
            "state": state.description,
            "failureCount": failureCount,
            "successCount": successCount,
            "requestsInHalfOpen": requestsInHalfOpen
        ]
        
        if let lastFailureTime = lastFailureTime {
            status["lastFailureTime"] = lastFailureTime
            status["timeSinceLastFailure"] = Date().timeIntervalSince(lastFailureTime)
        }
        
        return status
    }
    
    /**
     * Manually reset the circuit breaker to closed state.
     * 
     * This forces the circuit breaker back to normal operation.
     * Use this when you know the service has recovered and you want
     * to bypass the normal recovery process.
     */
    public func reset() async {
        logger.info("CircuitBreaker '\(name)' manually reset")
        
        state = .closed
        failureCount = 0
        successCount = 0
        requestsInHalfOpen = 0
        lastFailureTime = nil
    }
    
    /**
     * Manually open the circuit breaker.
     * 
     * This forces the circuit breaker into the open state, blocking
     * all requests. Use this when you know a service is down and you
     * want to prevent unnecessary requests.
     */
    public func open() async {
        logger.info("CircuitBreaker '\(name)' manually opened")
        
        state = .open
        lastFailureTime = Date()
    }
    
    // MARK: - Private Methods
    
    /**
     * Check if an operation should be allowed based on current state.
     * 
     * - Throws: KairoError.circuitOpen if the circuit is open
     * 
     * This method implements the core circuit breaker logic for deciding
     * whether to allow operations based on the current state.
     */
    private func checkOperationAllowed() async throws {
        switch state {
        case .closed:
            // Normal operation - allow all requests
            return
            
        case .open:
            // Check if enough time has passed to try half-open
            if let lastFailureTime = lastFailureTime {
                let timeSinceFailure = Date().timeIntervalSince(lastFailureTime)
                if timeSinceFailure >= config.timeoutSeconds {
                    // Move to half-open state
                    await transitionToHalfOpen()
                    return
                }
            }
            
            // Circuit is still open, block the request
            logger.debug("CircuitBreaker '\(name)' blocking request - circuit is open")
            throw KairoError.circuitOpen
            
        case .halfOpen:
            // Check if we've reached the limit for half-open requests
            if requestsInHalfOpen >= config.maxRequestsInHalfOpen {
                logger.debug("CircuitBreaker '\(name)' blocking request - half-open limit reached")
                throw KairoError.circuitOpen
            }
            
            // Allow the request but increment the counter
            requestsInHalfOpen += 1
            return
        }
    }
    
    /**
     * Record a successful operation and update circuit state.
     * 
     * This method is called when an operation succeeds. It updates
     * the success count and may transition the circuit to closed state.
     */
    private func recordSuccess() async {
        switch state {
        case .closed:
            // Reset failure count on success
            failureCount = 0
            
        case .open:
            // This shouldn't happen, but handle gracefully
            logger.warning("CircuitBreaker '\(name)' recorded success in open state")
            
        case .halfOpen:
            successCount += 1
            
            // Check if we have enough successes to close the circuit
            if successCount >= config.successThreshold {
                await transitionToClosed()
            }
        }
    }
    
    /**
     * Record a failed operation and update circuit state.
     * 
     * This method is called when an operation fails. It updates
     * the failure count and may transition the circuit to open state.
     */
    private func recordFailure() async {
        switch state {
        case .closed:
            failureCount += 1
            
            // Check if we should open the circuit
            if failureCount >= config.failureThreshold {
                await transitionToOpen()
            }
            
        case .open:
            // Update the failure time
            lastFailureTime = Date()
            
        case .halfOpen:
            // Any failure in half-open state should open the circuit
            await transitionToOpen()
        }
    }
    
    /**
     * Transition the circuit breaker to the open state.
     * 
     * This method is called when the failure threshold is reached.
     * It blocks all future requests until the timeout period expires.
     */
    private func transitionToOpen() async {
        logger.info("CircuitBreaker '\(name)' transitioning to OPEN state")
        
        state = .open
        lastFailureTime = Date()
        successCount = 0
        requestsInHalfOpen = 0
    }
    
    /**
     * Transition the circuit breaker to the half-open state.
     * 
     * This method is called when the timeout period expires and we want
     * to test if the service has recovered.
     */
    private func transitionToHalfOpen() async {
        logger.info("CircuitBreaker '\(name)' transitioning to HALF-OPEN state")
        
        state = .halfOpen
        successCount = 0
        requestsInHalfOpen = 0
    }
    
    /**
     * Transition the circuit breaker to the closed state.
     * 
     * This method is called when enough successful operations have been
     * recorded in the half-open state, indicating the service has recovered.
     */
    private func transitionToClosed() async {
        logger.info("CircuitBreaker '\(name)' transitioning to CLOSED state")
        
        state = .closed
        failureCount = 0
        successCount = 0
        requestsInHalfOpen = 0
        lastFailureTime = nil
    }
}

/**
 * CircuitBreakerManager - Manages multiple circuit breakers for different services
 * 
 * This class provides a convenient way to manage multiple circuit breakers
 * for different services or endpoints. It's useful when you need different
 * circuit breaker configurations for different parts of your system.
 */
public class CircuitBreakerManager {
    
    // MARK: - Properties
    
    /// Dictionary of circuit breakers for different services
    private var circuitBreakers: [String: CircuitBreaker] = [:]
    
    /// Logger for debugging and monitoring
    private let logger: Logger
    
    // MARK: - Initialization
    
    /**
     * Initialize the circuit breaker manager.
     * 
     * - Parameter logger: Logger instance for debugging
     */
    public init(logger: Logger) {
        self.logger = logger
        logger.info("CircuitBreakerManager initialized")
    }
    
    // MARK: - Public Methods
    
    /**
     * Get or create a circuit breaker for a specific service.
     * 
     * - Parameters:
     *   - serviceName: Name of the service (e.g., "api", "images", "auth")
     *   - config: Configuration for this circuit breaker
     * - Returns: The circuit breaker for this service
     * 
     * This method will create a new circuit breaker if one doesn't exist
     * for the service, or return the existing one.
     */
    public func getCircuitBreaker(for serviceName: String, config: CircuitBreakerConfiguration = .default) async -> CircuitBreaker {
        if let existing = circuitBreakers[serviceName] {
            return existing
        }
        
        let circuitBreaker = CircuitBreaker(name: serviceName, config: config, logger: logger)
        circuitBreakers[serviceName] = circuitBreaker
        
        logger.debug("Created circuit breaker for service '\(serviceName)'")
        return circuitBreaker
    }
    
    /**
     * Get status information for all circuit breakers.
     * 
     * - Returns: Dictionary of status information for each service
     * 
     * This is useful for monitoring and debugging the overall system.
     */
    public func getAllStatus() async -> [String: [String: Any]] {
        var status: [String: [String: Any]] = [:]
        
        for (serviceName, circuitBreaker) in circuitBreakers {
            status[serviceName] = await circuitBreaker.getStatus()
        }
        
        return status
    }
    
    /**
     * Reset all circuit breakers to closed state.
     * 
     * This forces all circuit breakers back to normal operation.
     * Use this when you know all services have recovered.
     */
    public func resetAll() async {
        logger.info("Resetting all circuit breakers...")
        
        for (serviceName, circuitBreaker) in circuitBreakers {
            await circuitBreaker.reset()
            logger.debug("Reset circuit breaker for '\(serviceName)'")
        }
        
        logger.info("All circuit breakers reset")
    }
}
