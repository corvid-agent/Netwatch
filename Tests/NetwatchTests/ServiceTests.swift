import Foundation
import XCTest
@testable import Netwatch

// MARK: - TrafficMonitor Parsing Tests

final class TrafficMonitorParsingTests: XCTestCase {

    let monitor = TrafficMonitor()

    func testParseNettopOutput() async {
        let output = """
        Safari.1234, 1048576, 524288
        Slack.5678, 102400, 51200
        """

        let snapshot = await monitor.parseNettopOutput(output)

        XCTAssertEqual(snapshot.processes.count, 2)
        XCTAssertEqual(snapshot.processes[0].processName, "Safari")
        XCTAssertEqual(snapshot.processes[0].bytesIn, 1_048_576)
        XCTAssertEqual(snapshot.processes[0].bytesOut, 524_288)
        XCTAssertEqual(snapshot.totalBytesIn, 1_048_576 + 102_400)
        XCTAssertEqual(snapshot.totalBytesOut, 524_288 + 51_200)
    }

    func testAggregatesSamePid() async {
        let output = """
        Safari.1234, 1000, 500
        Safari.1234, 2000, 1000
        """

        let snapshot = await monitor.parseNettopOutput(output)

        XCTAssertEqual(snapshot.processes.count, 1)
        XCTAssertEqual(snapshot.processes[0].bytesIn, 3000)
        XCTAssertEqual(snapshot.processes[0].bytesOut, 1500)
    }

    func testSkipsZeroTraffic() async {
        let output = """
        Safari.1234, 1000, 500
        IdleApp.5678, 0, 0
        """

        let snapshot = await monitor.parseNettopOutput(output)

        XCTAssertEqual(snapshot.processes.count, 1)
        XCTAssertEqual(snapshot.processes[0].processName, "Safari")
    }

    func testSkipsMalformedLines() async {
        let output = """
        Safari.1234, 1000, 500
        bad line
        another, bad
        , ,
        """

        let snapshot = await monitor.parseNettopOutput(output)

        XCTAssertEqual(snapshot.processes.count, 1)
    }

    func testSortsByBandwidth() async {
        let output = """
        Low.100, 100, 50
        High.200, 10000, 5000
        Mid.300, 1000, 500
        """

        let snapshot = await monitor.parseNettopOutput(output)

        XCTAssertEqual(snapshot.processes[0].processName, "High")
        XCTAssertEqual(snapshot.processes[1].processName, "Mid")
        XCTAssertEqual(snapshot.processes[2].processName, "Low")
    }

    func testParseLsofOutput() async {
        let output = """
        COMMAND    PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
        Safari    1234 user   10u  IPv4 0x1234 0t0      TCP 127.0.0.1:8080->10.0.0.1:443 (ESTABLISHED)
        node      5678 user   15u  IPv4 0x5678 0t0      TCP *:3000 (LISTEN)
        """

        let connections = await monitor.parseLsofOutput(output)

        XCTAssertEqual(connections.count, 2)

        let safari = connections.first { $0.processName == "Safari" }
        XCTAssertNotNil(safari)
        XCTAssertEqual(safari?.localPort, 8080)
        XCTAssertEqual(safari?.remoteAddress, "10.0.0.1")
        XCTAssertEqual(safari?.remotePort, 443)
        XCTAssertEqual(safari?.state, "ESTABLISHED")

        let node = connections.first { $0.processName == "node" }
        XCTAssertNotNil(node)
        XCTAssertEqual(node?.localPort, 3000)
        XCTAssertEqual(node?.state, "LISTEN")
    }

    func testDeduplicatesConnections() async {
        let output = """
        COMMAND    PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
        Safari    1234 user   10u  IPv4 0x1234 0t0      TCP 127.0.0.1:8080->10.0.0.1:443 (ESTABLISHED)
        Safari    1234 user   11u  IPv4 0x1235 0t0      TCP 127.0.0.1:8080->10.0.0.1:443 (ESTABLISHED)
        """

        let connections = await monitor.parseLsofOutput(output)
        XCTAssertEqual(connections.count, 1)
    }
}

// MARK: - InterfaceMonitor Parsing Tests

final class InterfaceMonitorParsingTests: XCTestCase {

    let monitor = InterfaceMonitor()

    func testParseNetstatOutput() async {
        let output = """
        Name  Mtu   Network       Address            Ipkts Ierrs Ibytes    Opkts Oerrs Obytes    Coll
        en0   1500  <Link#4>      aa:bb:cc:dd:ee:ff  10000 0     15000000  8000  0     5000000   0
        lo0   16384 <Link#1>                          5000  0     1000000   5000  0     1000000   0
        """

        let stats = await monitor.parseNetstatOutput(output)

        XCTAssertEqual(stats.count, 2)

        let en0 = stats.first { $0.name == "en0" }
        XCTAssertNotNil(en0)
        XCTAssertEqual(en0?.bytesIn, 15_000_000)
        XCTAssertEqual(en0?.bytesOut, 5_000_000)
        XCTAssertEqual(en0?.packetsIn, 10000)
        XCTAssertEqual(en0?.packetsOut, 8000)
    }

    func testSkipsMalformed() async {
        let output = """
        Name  Mtu   Network       Address            Ipkts Ierrs Ibytes    Opkts Oerrs Obytes    Coll
        short line
        en0   1500  <Link#4>      aa:bb:cc:dd:ee:ff  10000 0     15000000  8000  0     5000000   0
        """

        let stats = await monitor.parseNetstatOutput(output)
        XCTAssertEqual(stats.count, 1)
    }
}
