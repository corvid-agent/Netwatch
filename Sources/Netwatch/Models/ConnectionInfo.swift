import Foundation

/// Represents a network connection tracked by the system.
public struct ConnectionInfo: Sendable, Identifiable, Hashable {

    // MARK: - Transport

    public enum Transport: String, Sendable, CaseIterable {
        case tcp
        case udp
    }

    // MARK: - Direction

    public enum Direction: String, Sendable {
        case incoming
        case outgoing
        case both
    }

    // MARK: - Properties

    /// Process name.
    public let processName: String

    /// Process ID.
    public let pid: Int

    /// Local address.
    public let localAddress: String

    /// Local port.
    public let localPort: Int

    /// Remote address (nil for listening sockets).
    public let remoteAddress: String?

    /// Remote port (nil for listening sockets).
    public let remotePort: Int?

    /// Transport protocol.
    public let transport: Transport

    /// Connection state.
    public let state: String?

    /// Unique identifier.
    public var id: String {
        "\(pid)-\(localPort)-\(transport.rawValue)-\(remoteAddress ?? "")-\(remotePort ?? 0)"
    }

    /// Whether this is a loopback connection.
    public var isLocal: Bool {
        localAddress.hasPrefix("127.") || localAddress == "::1"
    }

    /// Whether this connection has a remote endpoint.
    public var isEstablished: Bool {
        remoteAddress != nil && state?.uppercased() == "ESTABLISHED"
    }
}
