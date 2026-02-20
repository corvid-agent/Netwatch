import Foundation

/// Bandwidth snapshot for a single process.
public struct ProcessTraffic: Sendable, Identifiable, Hashable {

    /// Process name.
    public let processName: String

    /// Process ID.
    public let pid: Int

    /// Bytes received per second.
    public let bytesIn: UInt64

    /// Bytes sent per second.
    public let bytesOut: UInt64

    /// Unique identifier.
    public var id: Int { pid }

    /// Total bytes per second.
    public var totalBytes: UInt64 { bytesIn + bytesOut }
}

/// A point-in-time snapshot of network traffic.
public struct TrafficSnapshot: Sendable {

    /// Per-process traffic data, sorted by total bandwidth.
    public let processes: [ProcessTraffic]

    /// Total bytes received per second across all processes.
    public let totalBytesIn: UInt64

    /// Total bytes sent per second across all processes.
    public let totalBytesOut: UInt64

    /// Active connection count.
    public let connectionCount: Int

    /// Timestamp of this snapshot.
    public let timestamp: Date

    /// Total bandwidth.
    public var totalBytes: UInt64 { totalBytesIn + totalBytesOut }

    /// Empty snapshot.
    public static let empty = TrafficSnapshot(
        processes: [],
        totalBytesIn: 0,
        totalBytesOut: 0,
        connectionCount: 0,
        timestamp: Date()
    )
}
