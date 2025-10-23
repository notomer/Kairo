import Foundation

public enum HealthLevel: Int, Sendable {
    case High, Medium, Low, Critical
}

public struct Policy: Sendable {
    public let maxNetworkConcurrent: Int
    public let allowBackgroundMl: Bool
    public let imageVariant: ImageVariant
    public let preferCacheWhenUnhealthy: Bool
    
    public enum ImageVariant: String, Sendable {
        case original
        case small
        case medium
        case large
    }
    
    public init(
    maxNetworkConcurrent: Int,
    allowBackgroundMl: Bool,
    imageVariant: ImageVariant,
    preferCacheWhenUnhealthy: Bool
    ) {
        self.maxNetworkConcurrent = maxNetworkConcurrent
        self.allowBackgroundMl = allowBackgroundMl
        self.imageVariant = imageVariant
        self.preferCacheWhenUnhealthy = preferCacheWhenUnhealthy
    }
}

public struct KairoConfig: Sendable {
    public var networkMaxConcurrent: Int
    public var lowBatteryThreshold: Float
    public var debounceMillis: Int

    public init(
        networkMaxConcurrent: Int = 6,
        lowBatteryThreshold: Float = 0.15,
        debounceMillis: Int = 350
    ) {
        self.networkMaxConcurrent = networkMaxConcurrent
        self.lowBatteryThreshold = lowBatteryThreshold
        self.debounceMillis = debounceMillis
    }

    public static let `default` = KairoConfig()
}

public enum KairoError: Error, Sendable {
    case cancelled
    case networkFailure
    case circuitOpen
}
