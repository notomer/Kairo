import Foundation
import Network

/**
 * NetClient - Intelligent network client with performance throttling
 * 
 * The NetClient is the main interface for making network requests in Kairo.
 * It automatically applies performance throttling based on device health conditions
 * and uses circuit breakers to handle service failures gracefully.
 * 
 * Key features:
 * - Automatic concurrency limiting based on device health
 * - Circuit breaker pattern for fault tolerance
 * - Request prioritization and queuing
 * - Automatic retry with exponential backoff
 * - Performance monitoring and metrics
 */

/**
 * NetworkRequest - Configuration for a network request
 * 
 * This struct contains all the information needed to make a network request,
 * including the URL, method, headers, and performance settings.
 */
public struct NetworkRequest: Sendable {
    /// The URL to request
    public let url: URL
    
    /// HTTP method (GET, POST, etc.)
    public let method: HTTPMethod
    
    /// Request headers
    public let headers: [String: String]
    
    /// Request body data
    public let body: Data?
    
    /// Request timeout in seconds
    public let timeout: TimeInterval
    
    /// Priority level for this request
    public let priority: RequestPriority
    
    /// Whether this request should be retried on failure
    public let shouldRetry: Bool
    
    /// Maximum number of retry attempts
    public let maxRetries: Int
    
    /**
     * HTTP methods supported by the network client
     */
    public enum HTTPMethod: String, Sendable {
        case GET = "GET"
        case POST = "POST"
        case PUT = "PUT"
        case DELETE = "DELETE"
        case PATCH = "PATCH"
        case HEAD = "HEAD"
        case OPTIONS = "OPTIONS"
    }
    
    /**
     * Request priority levels for handling during poor conditions
     */
    public enum RequestPriority: Int, Sendable, CaseIterable {
        case low = 1
        case normal = 2
        case high = 3
        case critical = 4
        
        /**
         * Get a human-readable description of this priority level
         */
        public var description: String {
            switch self {
            case .low: return "Low Priority"
            case .normal: return "Normal Priority"
            case .high: return "High Priority"
            case .critical: return "Critical Priority"
            }
        }
    }
    
    /**
     * Initialize a network request with all parameters
     * 
     * - Parameters:
     *   - url: The URL to request
     *   - method: HTTP method to use
     *   - headers: Request headers
     *   - body: Request body data
     *   - timeout: Request timeout in seconds
     *   - priority: Priority level for this request
     *   - shouldRetry: Whether to retry on failure
     *   - maxRetries: Maximum number of retry attempts
     */
    public init(
        url: URL,
        method: HTTPMethod = .GET,
        headers: [String: String] = [:],
        body: Data? = nil,
        timeout: TimeInterval = 30.0,
        priority: RequestPriority = .normal,
        shouldRetry: Bool = true,
        maxRetries: Int = 3
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.timeout = timeout
        self.priority = priority
        self.shouldRetry = shouldRetry
        self.maxRetries = maxRetries
    }
}

/**
 * NetworkResponse - Result of a network request
 * 
 * This struct contains the response data, status code, and metadata
 * from a completed network request.
 */
public struct NetworkResponse: Sendable {
    /// Response data
    public let data: Data
    
    /// HTTP status code
    public let statusCode: Int
    
    /// Response headers
    public let headers: [String: String]
    
    /// Request duration in seconds
    public let duration: TimeInterval
    
    /// Number of retry attempts made
    public let retryCount: Int
    
    /// Whether this was a successful response (status 200-299)
    public var isSuccess: Bool {
        return statusCode >= 200 && statusCode < 300
    }
    
    /**
     * Initialize a network response with all parameters
     */
    public init(
        data: Data,
        statusCode: Int,
        headers: [String: String],
        duration: TimeInterval,
        retryCount: Int = 0
    ) {
        self.data = data
        self.statusCode = statusCode
        self.headers = headers
        self.duration = duration
        self.retryCount = retryCount
    }
}

/**
 * NetClient - Main network client with intelligent throttling
 * 
 * This class provides a high-level interface for making network requests
 * with automatic performance throttling based on device health conditions.
 * It manages concurrency, implements circuit breakers, and handles retries.
 */
public class NetClient: ObservableObject {
    
    // MARK: - Properties
    
    /// Current performance policy from Kairo
    @Published public private(set) var currentPolicy: Policy?
    
    /// Semaphore for controlling concurrent requests
    private let semaphore: AsyncSemaphore
    
    /// Circuit breaker for fault tolerance
    private let circuitBreaker: CircuitBreaker
    
    /// Logger for debugging and monitoring
    private let logger: Logger
    
    /// URL session for making requests
    private let urlSession: URLSession
    
    /// Queue for managing request priorities
    private var requestQueue: [NetworkRequest] = []
    
    /// Current number of active requests
    private var activeRequestCount: Int = 0
    
    /// Performance metrics
    private var metrics = NetworkMetrics()
    
    // MARK: - Initialization
    
    /**
     * Initialize the network client with configuration
     * 
     * - Parameters:
     *   - maxConcurrent: Maximum concurrent requests allowed
     *   - logger: Logger instance for debugging
     * 
     * This creates a new NetClient that will automatically throttle
     * network requests based on device health conditions.
     */
    public init(maxConcurrent: Int = 6, logger: Logger) {
        self.logger = logger
        
        // Create semaphore for concurrency control
        self.semaphore = AsyncSemaphore(maxConcurrent: maxConcurrent, logger: logger)
        
        // Create circuit breaker for fault tolerance
        self.circuitBreaker = CircuitBreaker(name: "NetClient", logger: logger)
        
        // Configure URL session with appropriate timeouts
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        config.httpMaximumConnectionsPerHost = maxConcurrent
        
        self.urlSession = URLSession(configuration: config)
        
        logger.info("NetClient initialized with maxConcurrent: \(maxConcurrent)")
    }
    
    // MARK: - Public Methods
    
    /**
     * Update the performance policy based on current device health
     * 
     * - Parameter policy: New performance policy from Kairo
     * 
     * This method should be called whenever Kairo updates its performance
     * policy based on device health conditions. It will automatically
     * adjust the network client's behavior accordingly.
     */
    public func updatePolicy(_ policy: Policy) async {
        currentPolicy = policy
        
        // Update semaphore concurrency limit
        await semaphore.updateMaxConcurrent(policy.maxNetworkConcurrent)
        
        logger.info("NetClient policy updated: maxConcurrent=\(policy.maxNetworkConcurrent)")
    }
    
    /**
     * Make a network request with automatic throttling and fault tolerance
     * 
     * - Parameter request: The network request to make
     * - Returns: The network response
     * - Throws: KairoError if the request fails or is throttled
     * 
     * This is the main method for making network requests. It will:
     * - Check if the request should be allowed based on current policy
     * - Apply concurrency limiting using the semaphore
     * - Use circuit breaker pattern for fault tolerance
     * - Handle retries with exponential backoff
     * - Update performance metrics
     * 
     * Usage:
     * ```swift
     * let request = NetworkRequest(
     *     url: URL(string: "https://api.example.com/data")!,
     *     method: .GET,
     *     priority: .high
     * )
     * 
     * do {
     *     let response = try await netClient.request(request)
     *     // Handle successful response
     * } catch {
     *     // Handle error
     * }
     * ```
     */
    public func request(_ request: NetworkRequest) async throws -> NetworkResponse {
        let startTime = Date()
        
        // Check if request should be allowed based on current policy
        try await checkRequestAllowed(request)
        
        // Acquire semaphore permission
        try await semaphore.acquire()
        defer { Task { await semaphore.release() } }
        
        // Execute request through circuit breaker
        let response = try await circuitBreaker.execute {
            try await performRequest(request)
        }
        
        // Update metrics
        let duration = Date().timeIntervalSince(startTime)
        await updateMetrics(request: request, response: response, duration: duration)
        
        logger.debug("Request completed: \(request.url) in \(String(format: "%.2f", duration))s")
        
        return response
    }
    
    /**
     * Get current performance metrics
     * 
     * - Returns: Current network performance metrics
     * 
     * This provides information about request success rates, average
     * response times, and other performance indicators.
     */
    public func getMetrics() -> NetworkMetrics {
        return metrics
    }
    
    /**
     * Reset performance metrics
     * 
     * This clears all accumulated metrics and starts fresh.
     * Useful for testing or when you want to reset performance tracking.
     */
    public func resetMetrics() {
        metrics = NetworkMetrics()
        logger.info("Network metrics reset")
    }
    
    // MARK: - Private Methods
    
    /**
     * Check if a request should be allowed based on current policy
     * 
     * - Parameter request: The request to check
     * - Throws: KairoError if the request should be blocked
     * 
     * This method implements the policy-based request filtering logic.
     * It checks various conditions to determine if a request should proceed.
     */
    private func checkRequestAllowed(_ request: NetworkRequest) async throws {
        guard let policy = currentPolicy else {
            // No policy set, allow all requests
            return
        }
        
        // Check if we're at the concurrency limit
        let status = await semaphore.getStatus()
        if status.current >= policy.maxNetworkConcurrent {
            // Check if this is a high-priority request
            if request.priority != .critical {
                logger.debug("Request blocked due to concurrency limit: \(request.url)")
                throw KairoError.cancelled
            }
        }
        
        // Additional policy checks could be added here
        // For example, blocking certain types of requests during poor conditions
    }
    
    /**
     * Perform the actual network request
     * 
     * - Parameter request: The request to perform
     * - Returns: The network response
     * - Throws: NetworkError if the request fails
     * 
     * This method handles the actual HTTP request with retry logic
     * and error handling.
     */
    private func performRequest(_ request: NetworkRequest) async throws -> NetworkResponse {
        var retryCount = 0
        var lastError: Error?
        
        while retryCount <= request.maxRetries {
            do {
                return try await executeRequest(request)
            } catch {
                lastError = error
                retryCount += 1
                
                if retryCount <= request.maxRetries && request.shouldRetry {
                    // Calculate exponential backoff delay
                    let delay = pow(2.0, Double(retryCount - 1)) * 1.0
                    logger.debug("Request failed, retrying in \(delay)s (attempt \(retryCount)/\(request.maxRetries))")
                    
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    break
                }
            }
        }
        
        // If we get here, all retries failed
        throw lastError ?? NetworkError.requestFailed
    }
    
    /**
     * Execute a single network request
     * 
     * - Parameter request: The request to execute
     * - Returns: The network response
     * - Throws: NetworkError if the request fails
     * 
     * This method performs the actual HTTP request using URLSession.
     */
    private func executeRequest(_ request: NetworkRequest) async throws -> NetworkResponse {
        let startTime = Date()
        
        // Create URL request
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.timeoutInterval = request.timeout
        
        // Add headers
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add body if present
        if let body = request.body {
            urlRequest.httpBody = body
        }
        
        // Perform the request
        let (data, response) = try await urlSession.data(for: urlRequest)
        
        // Parse response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        // Extract headers
        var headers: [String: String] = [:]
        for (key, value) in httpResponse.allHeaderFields {
            if let key = key as? String, let value = value as? String {
                headers[key] = value
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        return NetworkResponse(
            data: data,
            statusCode: httpResponse.statusCode,
            headers: headers,
            duration: duration
        )
    }
    
    /**
     * Update performance metrics with request/response information
     * 
     * - Parameters:
     *   - request: The request that was made
     *   - response: The response received
     *   - duration: How long the request took
     * 
     * This method updates the internal metrics with information about
     * the completed request for performance monitoring.
     */
    private func updateMetrics(request: NetworkRequest, response: NetworkResponse, duration: TimeInterval) async {
        await metrics.recordRequest(
            success: response.isSuccess,
            duration: duration,
            priority: request.priority
        )
    }
}

/**
 * NetworkMetrics - Performance metrics for network operations
 * 
 * This class tracks various performance metrics for network operations,
 * including success rates, response times, and request counts.
 */
public class NetworkMetrics: Sendable {
    
    // MARK: - Properties
    
    /// Total number of requests made
    private var totalRequests: Int = 0
    
    /// Number of successful requests
    private var successfulRequests: Int = 0
    
    /// Number of failed requests
    private var failedRequests: Int = 0
    
    /// Total response time for all requests
    private var totalResponseTime: TimeInterval = 0
    
    /// Request counts by priority
    private var requestsByPriority: [NetworkRequest.RequestPriority: Int] = [:]
    
    /// Success rates by priority
    private var successRatesByPriority: [NetworkRequest.RequestPriority: (success: Int, total: Int)] = [:]
    
    // MARK: - Public Methods
    
    /**
     * Record a completed request in the metrics
     * 
     * - Parameters:
     *   - success: Whether the request was successful
     *   - duration: How long the request took
     *   - priority: The priority level of the request
     * 
     * This method updates all relevant metrics with information about
     * the completed request.
     */
    public func recordRequest(success: Bool, duration: TimeInterval, priority: NetworkRequest.RequestPriority) async {
        totalRequests += 1
        totalResponseTime += duration
        
        if success {
            successfulRequests += 1
        } else {
            failedRequests += 1
        }
        
        // Update priority-specific metrics
        requestsByPriority[priority, default: 0] += 1
        
        let current = successRatesByPriority[priority] ?? (success: 0, total: 0)
        if success {
            successRatesByPriority[priority] = (success: current.success + 1, total: current.total + 1)
        } else {
            successRatesByPriority[priority] = (success: current.success, total: current.total + 1)
        }
    }
    
    /**
     * Get the overall success rate
     * 
     * - Returns: Success rate as a percentage (0.0 to 1.0)
     */
    public func getSuccessRate() -> Double {
        guard totalRequests > 0 else { return 0.0 }
        return Double(successfulRequests) / Double(totalRequests)
    }
    
    /**
     * Get the average response time
     * 
     * - Returns: Average response time in seconds
     */
    public func getAverageResponseTime() -> TimeInterval {
        guard totalRequests > 0 else { return 0.0 }
        return totalResponseTime / Double(totalRequests)
    }
    
    /**
     * Get success rate for a specific priority level
     * 
     * - Parameter priority: The priority level to check
     * - Returns: Success rate for that priority (0.0 to 1.0)
     */
    public func getSuccessRate(for priority: NetworkRequest.RequestPriority) -> Double {
        guard let rates = successRatesByPriority[priority] else { return 0.0 }
        guard rates.total > 0 else { return 0.0 }
        return Double(rates.success) / Double(rates.total)
    }
    
    /**
     * Get comprehensive metrics summary
     * 
     * - Returns: Dictionary with all current metrics
     */
    public func getSummary() -> [String: Any] {
        var summary: [String: Any] = [
            "totalRequests": totalRequests,
            "successfulRequests": successfulRequests,
            "failedRequests": failedRequests,
            "successRate": getSuccessRate(),
            "averageResponseTime": getAverageResponseTime()
        ]
        
        // Add priority-specific metrics
        var priorityMetrics: [String: Any] = [:]
        for priority in NetworkRequest.RequestPriority.allCases {
            priorityMetrics[priority.description] = [
                "requestCount": requestsByPriority[priority] ?? 0,
                "successRate": getSuccessRate(for: priority)
            ]
        }
        summary["byPriority"] = priorityMetrics
        
        return summary
    }
}

/**
 * NetworkError - Errors that can occur during network operations
 * 
 * This enum defines all the possible errors that can occur when making
 * network requests through the NetClient.
 */
public enum NetworkError: Error, Sendable {
    case requestFailed
    case invalidResponse
    case timeout
    case noConnection
    case serverError(Int)
    case clientError(Int)
    case unknownError
    
    /**
     * Get a human-readable description of this error
     */
    public var description: String {
        switch self {
        case .requestFailed:
            return "Request failed"
        case .invalidResponse:
            return "Invalid response received"
        case .timeout:
            return "Request timed out"
        case .noConnection:
            return "No network connection"
        case .serverError(let code):
            return "Server error: \(code)"
        case .clientError(let code):
            return "Client error: \(code)"
        case .unknownError:
            return "Unknown error occurred"
        }
    }
}
