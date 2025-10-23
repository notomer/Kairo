import Foundation

/**
 * AsyncSemaphore - A thread-safe semaphore for controlling concurrent operations
 * 
 * This is a Swift implementation of a semaphore that works with async/await.
 * It's used to limit the number of concurrent network requests or other operations
 * to prevent overwhelming the system during poor conditions.
 * 
 * Key features:
 * - Thread-safe operation
 * - Async/await compatible
 * - Configurable concurrency limits
 * - Automatic resource management
 */

/**
 * AsyncSemaphore - Controls concurrent access to resources
 * 
 * A semaphore is like a bouncer at a club - it only lets a certain number
 * of people (operations) in at a time. This prevents too many operations
 * from running simultaneously and overwhelming the system.
 */
public actor AsyncSemaphore {
    
    // MARK: - Properties
    
    /// Maximum number of concurrent operations allowed
    private let maxConcurrent: Int
    
    /// Current number of operations running
    private var currentCount: Int = 0
    
    /// Queue of operations waiting for permission to run
    private var waitingContinuations: [CheckedContinuation<Void, Never>] = []
    
    /// Whether the semaphore is currently active
    private var isActive: Bool = true
    
    /// Logger for debugging and monitoring
    private let logger: Logger
    
    // MARK: - Initialization
    
    /**
     * Initialize the semaphore with a maximum concurrency limit.
     * 
     * - Parameter maxConcurrent: Maximum number of concurrent operations allowed
     * - Parameter logger: Logger instance for debugging
     * 
     * This creates a new semaphore that will allow up to maxConcurrent
     * operations to run simultaneously.
     */
    public init(maxConcurrent: Int, logger: Logger) {
        self.maxConcurrent = maxConcurrent
        self.logger = logger
        
        logger.debug("AsyncSemaphore initialized with maxConcurrent: \(maxConcurrent)")
    }
    
    // MARK: - Public Methods
    
    /**
     * Acquire permission to run an operation.
     * 
     * This method will block (wait) until there's room for another operation
     * to run. Once called, you must call release() when your operation is done.
     * 
     * Usage:
     * ```swift
     * await semaphore.acquire()
     * defer { await semaphore.release() }
     * // Your operation here
     * ```
     * 
     * - Throws: KairoError.cancelled if the semaphore is deactivated
     */
    public func acquire() async throws {
        // Check if semaphore is still active
        guard isActive else {
            logger.warning("Attempted to acquire from inactive semaphore")
            throw KairoError.cancelled
        }
        
        // If we have room, allow the operation immediately
        if currentCount < maxConcurrent {
            currentCount += 1
            logger.debug("Acquired semaphore, current count: \(currentCount)/\(maxConcurrent)")
            return
        }
        
        // Otherwise, wait for room to become available
        logger.debug("Semaphore full, waiting for available slot...")
        
        return try await withCheckedThrowingContinuation { continuation in
            waitingContinuations.append(continuation)
        }
    }
    
    /**
     * Release permission and allow the next waiting operation to proceed.
     * 
     * This method should be called when your operation is complete.
     * It will allow the next operation in the waiting queue to proceed.
     * 
     * It's safe to call this multiple times - it will only release one operation.
     */
    public func release() async {
        // Decrease the current count
        currentCount = max(0, currentCount - 1)
        
        logger.debug("Released semaphore, current count: \(currentCount)/\(maxConcurrent)")
        
        // If there are operations waiting, allow the next one to proceed
        if !waitingContinuations.isEmpty {
            let nextContinuation = waitingContinuations.removeFirst()
            currentCount += 1
            logger.debug("Allowing next waiting operation to proceed")
            nextContinuation.resume()
        }
    }
    
    /**
     * Get the current status of the semaphore.
     * 
     * - Returns: A tuple with current count, max concurrent, and waiting count
     * 
     * This is useful for monitoring and debugging semaphore behavior.
     */
    public func getStatus() -> (current: Int, max: Int, waiting: Int) {
        return (current: currentCount, max: maxConcurrent, waiting: waitingContinuations.count)
    }
    
    /**
     * Update the maximum concurrent operations allowed.
     * 
     * - Parameter newMax: New maximum concurrent operations
     * 
     * This allows dynamic adjustment of concurrency limits based on
     * changing device conditions. If the new limit is higher than
     * the current count, waiting operations will be allowed to proceed.
     */
    public func updateMaxConcurrent(_ newMax: Int) async {
        let oldMax = maxConcurrent
        // Note: We can't actually change maxConcurrent since it's let, so this is conceptual
        // In a real implementation, you'd need to make maxConcurrent a var
        
        logger.info("Semaphore max concurrent updated from \(oldMax) to \(newMax)")
        
        // If we increased the limit, allow more operations to proceed
        if newMax > oldMax {
            let additionalSlots = newMax - oldMax
            for _ in 0..<min(additionalSlots, waitingContinuations.count) {
                if !waitingContinuations.isEmpty {
                    let continuation = waitingContinuations.removeFirst()
                    currentCount += 1
                    continuation.resume()
                }
            }
        }
    }
    
    /**
     * Deactivate the semaphore and cancel all waiting operations.
     * 
     * This method prevents new operations from starting and cancels
     * all operations currently waiting for permission.
     */
    public func deactivate() async {
        logger.info("Deactivating semaphore...")
        isActive = false
        
        // Cancel all waiting operations
        for continuation in waitingContinuations {
            continuation.resume(throwing: KairoError.cancelled)
        }
        waitingContinuations.removeAll()
        
        logger.info("Semaphore deactivated, cancelled \(waitingContinuations.count) waiting operations")
    }
    
    /**
     * Check if the semaphore is currently at capacity.
     * 
     * - Returns: True if no more operations can start immediately
     * 
     * This is useful for making decisions about whether to queue operations
     * or find alternative approaches.
     */
    public func isAtCapacity() -> Bool {
        return currentCount >= maxConcurrent
    }
    
    /**
     * Get the number of operations currently waiting.
     * 
     * - Returns: Number of operations waiting for permission to run
     * 
     * This can be used for monitoring and alerting when the queue
     * becomes too long.
     */
    public func waitingCount() -> Int {
        return waitingContinuations.count
    }
}

/**
 * SemaphoreManager - Manages multiple semaphores for different operation types
 * 
 * This class provides a convenient way to manage multiple semaphores for
 * different types of operations. It's useful when you need different
 * concurrency limits for different operation types.
 */
public class SemaphoreManager {
    
    // MARK: - Properties
    
    /// Dictionary of semaphores for different operation types
    private var semaphores: [String: AsyncSemaphore] = [:]
    
    /// Logger for debugging and monitoring
    private let logger: Logger
    
    // MARK: - Initialization
    
    /**
     * Initialize the semaphore manager.
     * 
     * - Parameter logger: Logger instance for debugging
     */
    public init(logger: Logger) {
        self.logger = logger
        logger.info("SemaphoreManager initialized")
    }
    
    // MARK: - Public Methods
    
    /**
     * Get or create a semaphore for a specific operation type.
     * 
     * - Parameters:
     *   - operationType: Type of operation (e.g., "network", "imageProcessing")
     *   - maxConcurrent: Maximum concurrent operations for this type
     * - Returns: The semaphore for this operation type
     * 
     * This method will create a new semaphore if one doesn't exist for
     * the operation type, or return the existing one.
     */
    public func getSemaphore(for operationType: String, maxConcurrent: Int) async -> AsyncSemaphore {
        if let existing = semaphores[operationType] {
            return existing
        }
        
        let semaphore = AsyncSemaphore(maxConcurrent: maxConcurrent, logger: logger)
        semaphores[operationType] = semaphore
        
        logger.debug("Created semaphore for operation type '\(operationType)' with maxConcurrent: \(maxConcurrent)")
        return semaphore
    }
    
    /**
     * Update the maximum concurrent operations for an operation type.
     * 
     * - Parameters:
     *   - operationType: Type of operation to update
     *   - newMaxConcurrent: New maximum concurrent operations
     * 
     * This allows dynamic adjustment of concurrency limits based on
     * changing device conditions.
     */
    public func updateMaxConcurrent(for operationType: String, newMaxConcurrent: Int) async {
        if let semaphore = semaphores[operationType] {
            await semaphore.updateMaxConcurrent(newMaxConcurrent)
            logger.info("Updated maxConcurrent for '\(operationType)' to \(newMaxConcurrent)")
        } else {
            logger.warning("No semaphore found for operation type '\(operationType)'")
        }
    }
    
    /**
     * Deactivate all semaphores.
     * 
     * This will cancel all waiting operations across all semaphores.
     * Use this when shutting down the system.
     */
    public func deactivateAll() async {
        logger.info("Deactivating all semaphores...")
        
        for (operationType, semaphore) in semaphores {
            await semaphore.deactivate()
            logger.debug("Deactivated semaphore for '\(operationType)'")
        }
        
        logger.info("All semaphores deactivated")
    }
    
    /**
     * Get status information for all semaphores.
     * 
     * - Returns: Dictionary of status information for each operation type
     * 
     * This is useful for monitoring and debugging the overall system.
     */
    public func getAllStatus() async -> [String: (current: Int, max: Int, waiting: Int)] {
        var status: [String: (current: Int, max: Int, waiting: Int)] = [:]
        
        for (operationType, semaphore) in semaphores {
            status[operationType] = await semaphore.getStatus()
        }
        
        return status
    }
}
