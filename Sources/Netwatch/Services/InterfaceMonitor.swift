@preconcurrency import Foundation
import SystemConfiguration

/// Actor responsible for reading network interface statistics.
public actor InterfaceMonitor {

    // MARK: - Types

    /// Network interface statistics.
    public struct InterfaceStats: Sendable {
        /// Interface name (e.g., "en0", "lo0").
        public let name: String

        /// Total bytes received since boot.
        public let bytesIn: UInt64

        /// Total bytes sent since boot.
        public let bytesOut: UInt64

        /// Total packets received since boot.
        public let packetsIn: UInt64

        /// Total packets sent since boot.
        public let packetsOut: UInt64
    }

    // MARK: - State

    private var previousStats: [String: InterfaceStats] = [:]
    private var previousTimestamp: Date?

    // MARK: - Initializers

    public init() {}

    // MARK: - Public Methods

    /// Gets current per-second rates by comparing with previous sample.
    public func sampleRates() async -> (bytesIn: UInt64, bytesOut: UInt64) {
        let current = await readInterfaceStats()
        let now = Date()

        defer {
            previousStats = Dictionary(uniqueKeysWithValues: current.map { ($0.name, $0) })
            previousTimestamp = now
        }

        guard let prevTime = previousTimestamp else {
            return (bytesIn: 0, bytesOut: 0)
        }

        let elapsed = now.timeIntervalSince(prevTime)
        guard elapsed > 0 else { return (bytesIn: 0, bytesOut: 0) }

        var totalDeltaIn: UInt64 = 0
        var totalDeltaOut: UInt64 = 0

        for stat in current {
            guard !stat.name.hasPrefix("lo") else { continue } // skip loopback

            if let prev = previousStats[stat.name] {
                let deltaIn = stat.bytesIn >= prev.bytesIn ? stat.bytesIn - prev.bytesIn : stat.bytesIn
                let deltaOut = stat.bytesOut >= prev.bytesOut ? stat.bytesOut - prev.bytesOut : stat.bytesOut
                totalDeltaIn += UInt64(Double(deltaIn) / elapsed)
                totalDeltaOut += UInt64(Double(deltaOut) / elapsed)
            }
        }

        return (bytesIn: totalDeltaIn, bytesOut: totalDeltaOut)
    }

    // MARK: - Private Methods

    private func readInterfaceStats() async -> [InterfaceStats] {
        let output = try? await runNetstat()
        guard let output = output else { return [] }
        return parseNetstatOutput(output)
    }

    private func runNetstat() async throws -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/sbin/netstat")
        process.arguments = ["-ib"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        try process.run()

        return await withCheckedContinuation { continuation in
            process.terminationHandler = { @Sendable _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: output)
            }
        }
    }

    func parseNetstatOutput(_ output: String) -> [InterfaceStats] {
        var stats: [String: InterfaceStats] = [:]
        let lines = output.components(separatedBy: "\n")

        for line in lines.dropFirst() {
            let columns = line.split(separator: " ", omittingEmptySubsequences: true)
            // Name Mtu Network Address Ipkts Ierrs Ibytes Opkts Oerrs Obytes Coll
            guard columns.count >= 11 else { continue }

            let name = String(columns[0])
            guard let packetsIn = UInt64(columns[4]),
                  let bytesIn = UInt64(columns[6]),
                  let packetsOut = UInt64(columns[7]),
                  let bytesOut = UInt64(columns[9]) else { continue }

            // Aggregate multiple entries for the same interface
            if var existing = stats[name] {
                existing = InterfaceStats(
                    name: name,
                    bytesIn: existing.bytesIn + bytesIn,
                    bytesOut: existing.bytesOut + bytesOut,
                    packetsIn: existing.packetsIn + packetsIn,
                    packetsOut: existing.packetsOut + packetsOut
                )
                stats[name] = existing
            } else {
                stats[name] = InterfaceStats(
                    name: name,
                    bytesIn: bytesIn,
                    bytesOut: bytesOut,
                    packetsIn: packetsIn,
                    packetsOut: packetsOut
                )
            }
        }

        return Array(stats.values)
    }
}
