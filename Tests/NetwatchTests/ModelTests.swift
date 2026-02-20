import Foundation
import XCTest
@testable import Netwatch

// MARK: - ByteFormatter Tests

final class ByteFormatterTests: XCTestCase {
    func testFormatBytes() {
        XCTAssertEqual(ByteFormatter.format(bytes: UInt64(0)), "0 B")
        XCTAssertEqual(ByteFormatter.format(bytes: UInt64(512)), "512 B")
        XCTAssertEqual(ByteFormatter.format(bytes: UInt64(1024)), "1.0 KB")
        XCTAssertEqual(ByteFormatter.format(bytes: UInt64(1536)), "1.5 KB")
        XCTAssertEqual(ByteFormatter.format(bytes: UInt64(1_048_576)), "1.0 MB")
        XCTAssertEqual(ByteFormatter.format(bytes: UInt64(1_073_741_824)), "1.0 GB")
    }

    func testFormatRate() {
        XCTAssertEqual(ByteFormatter.formatRate(bytesPerSecond: 0), "0 B/s")
        XCTAssertEqual(ByteFormatter.formatRate(bytesPerSecond: 1024), "1.0 KB/s")
        XCTAssertEqual(ByteFormatter.formatRate(bytesPerSecond: 1_048_576), "1.0 MB/s")
    }

    func testShortRate() {
        XCTAssertEqual(ByteFormatter.shortRate(bytesPerSecond: 0), "0B")
        XCTAssertEqual(ByteFormatter.shortRate(bytesPerSecond: 512), "512B")
        XCTAssertEqual(ByteFormatter.shortRate(bytesPerSecond: 1024), "1.0K")
        XCTAssertEqual(ByteFormatter.shortRate(bytesPerSecond: 1_048_576), "1.0M")
        XCTAssertEqual(ByteFormatter.shortRate(bytesPerSecond: 1_073_741_824), "1.0G")
        XCTAssertEqual(ByteFormatter.shortRate(bytesPerSecond: 15_728_640), "15.0M")
        XCTAssertEqual(ByteFormatter.shortRate(bytesPerSecond: 157_286_400), "150M")
    }
}

// MARK: - ConnectionInfo Tests

final class ConnectionInfoTests: XCTestCase {
    func testIsLocal() {
        let local = ConnectionInfo(
            processName: "test", pid: 1,
            localAddress: "127.0.0.1", localPort: 8080,
            remoteAddress: nil, remotePort: nil,
            transport: .tcp, state: nil
        )
        XCTAssertTrue(local.isLocal)

        let ipv6Local = ConnectionInfo(
            processName: "test", pid: 1,
            localAddress: "::1", localPort: 8080,
            remoteAddress: nil, remotePort: nil,
            transport: .tcp, state: nil
        )
        XCTAssertTrue(ipv6Local.isLocal)

        let remote = ConnectionInfo(
            processName: "test", pid: 1,
            localAddress: "192.168.1.1", localPort: 8080,
            remoteAddress: nil, remotePort: nil,
            transport: .tcp, state: nil
        )
        XCTAssertFalse(remote.isLocal)
    }

    func testIsEstablished() {
        let established = ConnectionInfo(
            processName: "test", pid: 1,
            localAddress: "192.168.1.1", localPort: 8080,
            remoteAddress: "10.0.0.1", remotePort: 443,
            transport: .tcp, state: "ESTABLISHED"
        )
        XCTAssertTrue(established.isEstablished)

        let listening = ConnectionInfo(
            processName: "test", pid: 1,
            localAddress: "0.0.0.0", localPort: 8080,
            remoteAddress: nil, remotePort: nil,
            transport: .tcp, state: "LISTEN"
        )
        XCTAssertFalse(listening.isEstablished)
    }

    func testUniqueId() {
        let conn1 = ConnectionInfo(
            processName: "test", pid: 1,
            localAddress: "127.0.0.1", localPort: 8080,
            remoteAddress: "10.0.0.1", remotePort: 443,
            transport: .tcp, state: nil
        )
        let conn2 = ConnectionInfo(
            processName: "test", pid: 1,
            localAddress: "127.0.0.1", localPort: 8080,
            remoteAddress: "10.0.0.2", remotePort: 443,
            transport: .tcp, state: nil
        )
        XCTAssertNotEqual(conn1.id, conn2.id)
    }
}

// MARK: - TrafficSnapshot Tests

final class TrafficSnapshotTests: XCTestCase {
    func testEmptySnapshot() {
        let empty = TrafficSnapshot.empty
        XCTAssertTrue(empty.processes.isEmpty)
        XCTAssertEqual(empty.totalBytesIn, 0)
        XCTAssertEqual(empty.totalBytesOut, 0)
        XCTAssertEqual(empty.connectionCount, 0)
        XCTAssertEqual(empty.totalBytes, 0)
    }

    func testTotalBytes() {
        let snapshot = TrafficSnapshot(
            processes: [],
            totalBytesIn: 1024,
            totalBytesOut: 2048,
            connectionCount: 5,
            timestamp: Date()
        )
        XCTAssertEqual(snapshot.totalBytes, 3072)
    }
}

// MARK: - ProcessTraffic Tests

final class ProcessTrafficTests: XCTestCase {
    func testTotalBytes() {
        let process = ProcessTraffic(
            processName: "Safari",
            pid: 1234,
            bytesIn: 1_048_576,
            bytesOut: 524_288
        )
        XCTAssertEqual(process.totalBytes, 1_572_864)
        XCTAssertEqual(process.id, 1234)
    }
}
