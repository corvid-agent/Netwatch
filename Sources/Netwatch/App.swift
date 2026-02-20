import SwiftUI

@main
struct NetwatchApp: App {

    // MARK: - Properties

    @StateObject private var appState = AppState()

    // MARK: - Body

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "arrow.up.arrow.down.circle")
                    .font(.system(size: 12))

                if appState.showRateInMenuBar {
                    Text(appState.menuBarLabel)
                        .font(.system(size: 10, design: .monospaced))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - App State

/// Main application state managing traffic monitoring and connections.
@MainActor
final class AppState: ObservableObject {

    // MARK: - Published Properties

    @Published var traffic: TrafficSnapshot = .empty
    @Published var connections: [ConnectionInfo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var showRateInMenuBar = true
    @Published var refreshInterval: TimeInterval = 3.0
    @Published var interfaceBytesIn: UInt64 = 0
    @Published var interfaceBytesOut: UInt64 = 0

    // MARK: - Services

    let monitor = TrafficMonitor()
    var interfaceMonitor = InterfaceMonitor()

    // MARK: - Private

    private var refreshTask: Task<Void, Never>?

    // MARK: - Computed Properties

    var menuBarLabel: String {
        let down = ByteFormatter.shortRate(bytesPerSecond: interfaceBytesIn)
        let up = ByteFormatter.shortRate(bytesPerSecond: interfaceBytesOut)
        return "\u{2193}\(down) \u{2191}\(up)"
    }

    var filteredProcesses: [ProcessTraffic] {
        guard !searchText.isEmpty else { return traffic.processes }
        let lowered = searchText.lowercased()
        return traffic.processes.filter {
            $0.processName.lowercased().contains(lowered) ||
            String($0.pid).contains(lowered)
        }
    }

    var filteredConnections: [ConnectionInfo] {
        guard !searchText.isEmpty else { return connections }
        let lowered = searchText.lowercased()
        return connections.filter {
            $0.processName.lowercased().contains(lowered) ||
            String($0.pid).contains(lowered) ||
            $0.localAddress.contains(lowered) ||
            (String($0.localPort)).contains(lowered) ||
            ($0.remoteAddress?.lowercased().contains(lowered) ?? false)
        }
    }

    var establishedCount: Int {
        connections.filter { $0.isEstablished }.count
    }

    var listeningCount: Int {
        connections.filter { $0.state?.uppercased() == "LISTEN" }.count
    }

    // MARK: - Initializers

    init() {
        startMonitoring()
    }

    deinit {
        refreshTask?.cancel()
    }

    // MARK: - Public Methods

    func refresh() async {
        isLoading = true
        errorMessage = nil

        do {
            async let trafficResult = monitor.snapshot()
            async let connectionsResult = monitor.connections()
            async let ratesResult = interfaceMonitor.sampleRates()

            traffic = try await trafficResult
            connections = try await connectionsResult
            let rates = await ratesResult
            interfaceBytesIn = rates.bytesIn
            interfaceBytesOut = rates.bytesOut
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Private Methods

    private func startMonitoring() {
        refreshTask = Task { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                await self.refresh()
                try? await Task.sleep(for: .seconds(self.refreshInterval))
            }
        }
    }
}
