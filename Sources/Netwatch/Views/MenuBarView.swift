import SwiftUI

/// Menu bar popup view displaying network traffic and connections.
struct MenuBarView: View {

    // MARK: - Types

    enum Tab: String, CaseIterable {
        case traffic = "Traffic"
        case connections = "Connections"
    }

    // MARK: - Properties

    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: Tab = .traffic
    @State private var hoveredProcess: Int?
    @FocusState private var isSearchFocused: Bool

    private let accent = Theme.accent
    private let upload = Theme.upload
    private let download = Theme.download

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            Divider().opacity(0.3)
            tabPicker
            Divider().opacity(0.3)
            searchField
            Divider().opacity(0.3)

            switch selectedTab {
            case .traffic:
                trafficView
            case .connections:
                connectionsView
            }

            Divider().opacity(0.3)
            footerView
        }
        .frame(width: 380)
        .background(Color(nsColor: .windowBackgroundColor))
        .background {
            VStack {
                Button("Refresh") { Task { await appState.refresh() } }
                    .keyboardShortcut("r", modifiers: .command)
                Button("Search") { isSearchFocused = true }
                    .keyboardShortcut("f", modifiers: .command)
                Button("Clear") { appState.searchText = "" }
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .opacity(0)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 1) {
                Text("netwatch")
                    .font(.system(.title3, design: .monospaced, weight: .bold))
                    .foregroundStyle(accent)

                HStack(spacing: 8) {
                    Label(
                        ByteFormatter.formatRate(bytesPerSecond: appState.interfaceBytesIn),
                        systemImage: "arrow.down"
                    )
                    .foregroundStyle(download)

                    Label(
                        ByteFormatter.formatRate(bytesPerSecond: appState.interfaceBytesOut),
                        systemImage: "arrow.up"
                    )
                    .foregroundStyle(upload)
                }
                .font(Theme.monoSmall)
            }

            Spacer()

            Button(action: { Task { await appState.refresh() } }) {
                Group {
                    if appState.isLoading {
                        ProgressView()
                            .scaleEffect(0.5)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14))
                    }
                }
                .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(accent)
            .disabled(appState.isLoading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    Text(tab.rawValue.lowercased())
                        .font(Theme.monoSmall)
                        .foregroundStyle(selectedTab == tab ? accent : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(selectedTab == tab ? accent.opacity(0.1) : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(accent)

            TextField("filter...", text: $appState.searchText)
                .textFieldStyle(.plain)
                .font(Theme.mono)
                .focused($isSearchFocused)

            if !appState.searchText.isEmpty {
                Button(action: { appState.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Traffic View

    private var trafficView: some View {
        Group {
            if appState.isLoading && appState.traffic.processes.isEmpty {
                VStack(spacing: 8) {
                    ProgressView().scaleEffect(0.8)
                    Text("scanning...")
                        .font(Theme.mono)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 100)
            } else if appState.filteredProcesses.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "network.slash")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text("no traffic")
                        .font(Theme.mono)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 100)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(appState.filteredProcesses) { process in
                            processRow(process)
                        }
                    }
                }
                .frame(maxHeight: 340)
            }
        }
    }

    private func processRow(_ process: ProcessTraffic) -> some View {
        HStack(spacing: 0) {
            // Process name
            Text(process.processName)
                .font(Theme.monoSmall)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Download rate
            HStack(spacing: 2) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 8))
                Text(ByteFormatter.formatRate(bytesPerSecond: process.bytesIn))
            }
            .font(Theme.monoTiny)
            .foregroundStyle(download)
            .frame(width: 85, alignment: .trailing)

            // Upload rate
            HStack(spacing: 2) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 8))
                Text(ByteFormatter.formatRate(bytesPerSecond: process.bytesOut))
            }
            .font(Theme.monoTiny)
            .foregroundStyle(upload)
            .frame(width: 85, alignment: .trailing)

            // PID
            Text(String(process.pid))
                .font(Theme.monoTiny)
                .foregroundStyle(.tertiary)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(hoveredProcess == process.pid ? Color.primary.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hoveredProcess = $0 ? process.pid : nil }
        .contextMenu {
            Text("\(process.processName) (PID \(process.pid))")
            Divider()
            Button("Copy PID") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(String(process.pid), forType: .string)
            }
            Button("Copy Name") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(process.processName, forType: .string)
            }
        }
    }

    // MARK: - Connections View

    private var connectionsView: some View {
        Group {
            if appState.filteredConnections.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "link.badge.plus")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text("no connections")
                        .font(Theme.mono)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 100)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(appState.filteredConnections) { conn in
                            connectionRow(conn)
                        }
                    }
                }
                .frame(maxHeight: 340)
            }
        }
    }

    private func connectionRow(_ conn: ConnectionInfo) -> some View {
        HStack(spacing: 0) {
            // State dot
            Circle()
                .fill(connectionColor(conn))
                .frame(width: 6, height: 6)
                .frame(width: 14)

            // Process
            Text(conn.processName)
                .font(Theme.monoTiny)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(width: 80, alignment: .leading)

            // Protocol
            Text(conn.transport.rawValue)
                .font(Theme.monoTiny)
                .foregroundStyle(conn.transport == .tcp ? .cyan : .orange)
                .frame(width: 28)

            // Local port
            Text(":\(conn.localPort)")
                .font(Theme.monoTiny)
                .foregroundStyle(accent)
                .frame(width: 50, alignment: .trailing)

            // Arrow
            if conn.remoteAddress != nil {
                Text("\u{2192}")
                    .font(.system(size: 8))
                    .foregroundStyle(.quaternary)
                    .frame(width: 16)

                // Remote
                Text("\(conn.remoteAddress ?? ""):\(conn.remotePort ?? 0)")
                    .font(Theme.monoTiny)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("listening")
                    .font(Theme.monoTiny)
                    .foregroundStyle(.quaternary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 16)
            }

            // State
            Text(conn.state ?? "")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.quaternary)
                .frame(width: 45, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .contextMenu {
            Text("\(conn.processName) :\(conn.localPort)")
            Divider()
            Button("Copy Local Address") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("\(conn.localAddress):\(conn.localPort)", forType: .string)
            }
            if let remote = conn.remoteAddress {
                Button("Copy Remote Address") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("\(remote):\(conn.remotePort ?? 0)", forType: .string)
                }
            }
            Button("Copy PID") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(String(conn.pid), forType: .string)
            }
        }
    }

    private func connectionColor(_ conn: ConnectionInfo) -> Color {
        switch conn.state?.uppercased() {
        case "ESTABLISHED": return .green
        case "LISTEN": return accent
        case "TIME_WAIT", "CLOSE_WAIT": return .yellow
        case "SYN_SENT", "SYN_RECEIVED": return .orange
        default: return .gray
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    Circle().fill(.green).frame(width: 6, height: 6)
                    Text("\(appState.establishedCount)")
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 2) {
                    Circle().fill(accent).frame(width: 6, height: 6)
                    Text("\(appState.listeningCount)")
                        .foregroundStyle(.secondary)
                }
                Text("\(appState.connections.count) total")
                    .foregroundStyle(.quaternary)
            }
            .font(Theme.monoTiny)

            Spacer()

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Text("quit")
                    .font(Theme.monoSmall)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
