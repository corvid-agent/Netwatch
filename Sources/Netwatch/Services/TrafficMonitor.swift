@preconcurrency import Foundation

/// Actor responsible for monitoring network traffic using nettop.
public actor TrafficMonitor {

    // MARK: - Types

    public enum MonitorError: Error, LocalizedError, Sendable {
        case processExecutionFailed(String)
        case parsingFailed(String)

        public var errorDescription: String? {
            switch self {
            case .processExecutionFailed(let message):
                return "Failed to execute nettop: \(message)"
            case .parsingFailed(let message):
                return "Failed to parse output: \(message)"
            }
        }
    }

    // MARK: - Initializers

    public init() {}

    // MARK: - Public Methods

    /// Takes a snapshot of current network traffic using nettop.
    public func snapshot() async throws -> TrafficSnapshot {
        let output = try await runNettop()
        return parseNettopOutput(output)
    }

    /// Gets active connections using lsof.
    public func connections() async throws -> [ConnectionInfo] {
        let output = try await runLsof()
        return parseLsofOutput(output)
    }

    // MARK: - nettop

    private func runNettop() async throws -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        // -P: show per-process, -L 1: one sample, -J bytes_in,bytes_out
        process.arguments = ["-P", "-L", "1", "-k", "time,interface,state,rx_dupe,rx_ooo,re-tx,rtt_avg,rcvsize,tx_win,tc_class,tc_mgt,cc_algo,P,C,R,W,arch", "-t", "external"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw MonitorError.processExecutionFailed(error.localizedDescription)
        }

        return await withCheckedContinuation { continuation in
            process.terminationHandler = { @Sendable _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: output)
            }
        }
    }

    func parseNettopOutput(_ output: String) -> TrafficSnapshot {
        var processTraffic: [Int: (name: String, bytesIn: UInt64, bytesOut: UInt64)] = [:]
        let lines = output.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // nettop outputs: process.pid, bytes_in, bytes_out
            let columns = trimmed.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }

            guard columns.count >= 3 else { continue }

            let processField = columns[0]
            guard let bytesIn = UInt64(columns[1]),
                  let bytesOut = UInt64(columns[2]) else { continue }

            // Parse "processName.pid" format
            let (name, pid) = parseProcessField(processField)
            guard let pid = pid, bytesIn > 0 || bytesOut > 0 else { continue }

            if var existing = processTraffic[pid] {
                existing.bytesIn += bytesIn
                existing.bytesOut += bytesOut
                processTraffic[pid] = existing
            } else {
                processTraffic[pid] = (name: name, bytesIn: bytesIn, bytesOut: bytesOut)
            }
        }

        let processes = processTraffic.map { (pid, data) in
            ProcessTraffic(
                processName: data.name,
                pid: pid,
                bytesIn: data.bytesIn,
                bytesOut: data.bytesOut
            )
        }.sorted { $0.totalBytes > $1.totalBytes }

        let totalIn = processes.reduce(UInt64(0)) { $0 + $1.bytesIn }
        let totalOut = processes.reduce(UInt64(0)) { $0 + $1.bytesOut }

        return TrafficSnapshot(
            processes: processes,
            totalBytesIn: totalIn,
            totalBytesOut: totalOut,
            connectionCount: processes.count,
            timestamp: Date()
        )
    }

    private func parseProcessField(_ field: String) -> (String, Int?) {
        // Format: "processName.pid" or just "processName"
        guard let dotIndex = field.lastIndex(of: ".") else {
            return (field, nil)
        }

        let name = String(field[field.startIndex..<dotIndex])
        let pidString = String(field[field.index(after: dotIndex)...])

        if let pid = Int(pidString) {
            return (name, pid)
        }

        return (field, nil)
    }

    // MARK: - lsof

    private func runLsof() async throws -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-i", "-P", "-n"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw MonitorError.processExecutionFailed(error.localizedDescription)
        }

        return await withCheckedContinuation { continuation in
            process.terminationHandler = { @Sendable _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: output)
            }
        }
    }

    func parseLsofOutput(_ output: String) -> [ConnectionInfo] {
        var connections: [ConnectionInfo] = []
        var seen: Set<String> = []
        let lines = output.components(separatedBy: "\n")

        for line in lines.dropFirst() {
            let components = line.split(separator: " ", omittingEmptySubsequences: true)
            guard components.count >= 9 else { continue }

            let command = String(components[0])
            guard let pid = Int(components[1]) else { continue }

            let nodeType = String(components[7])
            let transport: ConnectionInfo.Transport
            switch nodeType.uppercased() {
            case "TCP": transport = .tcp
            case "UDP": transport = .udp
            default: continue
            }

            let nameField = components[8...].joined(separator: " ")
            let (localAddr, localPort, remoteAddr, remotePort, state) = parseConnectionField(nameField)

            guard let localPort = localPort else { continue }

            let key = "\(pid)-\(localPort)-\(transport.rawValue)-\(remoteAddr ?? "")-\(remotePort ?? 0)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)

            connections.append(ConnectionInfo(
                processName: command,
                pid: pid,
                localAddress: localAddr,
                localPort: localPort,
                remoteAddress: remoteAddr,
                remotePort: remotePort,
                transport: transport,
                state: state
            ))
        }

        return connections
    }

    private func parseConnectionField(_ name: String) -> (String, Int?, String?, Int?, String?) {
        var state: String?
        let parts = name.components(separatedBy: " ")
        var addressPart = parts[0]

        if parts.count > 1 {
            let statePart = parts.last ?? ""
            if statePart.hasPrefix("(") && statePart.hasSuffix(")") {
                state = String(statePart.dropFirst().dropLast())
            }
        }

        var remoteAddr: String?
        var remotePort: Int?

        if addressPart.contains("->") {
            let connectionParts = addressPart.components(separatedBy: "->")
            if connectionParts.count == 2 {
                let remote = connectionParts[1]
                if let colonIndex = remote.lastIndex(of: ":") {
                    remoteAddr = String(remote[remote.startIndex..<colonIndex])
                    remotePort = Int(String(remote[remote.index(after: colonIndex)...]))
                }
                addressPart = connectionParts[0]
            }
        }

        var localAddr = addressPart
        var localPort: Int?

        if let colonIndex = addressPart.lastIndex(of: ":") {
            localAddr = String(addressPart[addressPart.startIndex..<colonIndex])
            localPort = Int(String(addressPart[addressPart.index(after: colonIndex)...]))
        }

        return (localAddr, localPort, remoteAddr, remotePort, state)
    }
}
