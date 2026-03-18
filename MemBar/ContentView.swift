import SwiftUI

// MARK: - Main Menu View

struct MemoryMenuView: View {
    @ObservedObject var monitor: MemoryMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeroSection(monitor: monitor)

            Divider()
                .padding(.vertical, 8)

            UsageSection(monitor: monitor)

            Divider()
                .padding(.vertical, 8)

            ProcessesSection(monitor: monitor)

            Divider()
                .padding(.vertical, 8)

            DetailsSection(monitor: monitor)

            Divider()
                .padding(.vertical, 8)

            ActionsSection(monitor: monitor)
        }
        .padding(12)
        .frame(width: 240)
    }
}

// MARK: - Hero Section

private struct HeroSection: View {
    @ObservedObject var monitor: MemoryMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(usedGBText)
                            .font(.system(size: 42, weight: .medium, design: .rounded))
                            .monospacedDigit()
                        Text("GB")
                            .font(.system(size: 24, weight: .regular))
                            .foregroundColor(.secondary)
                    }

                    Text("of \(monitor.formatBytesWhole(monitor.totalBytes)) used")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                PressureBadge(level: monitor.pressureLevel)
            }
        }
    }

    private var usedGBText: String {
        let gb = Double(monitor.usedBytes) / 1_073_741_824
        return String(format: "%.1f", gb)
    }
}

// MARK: - Pressure Badge

private struct PressureBadge: View {
    let level: MemoryMonitor.PressureLevel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(level.rawValue)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(foregroundColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(backgroundColor)
        .clipShape(Capsule())
    }

    private var foregroundColor: Color {
        switch level {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }

    private var backgroundColor: Color {
        switch level {
        case .normal: return .green.opacity(0.15)
        case .warning: return .orange.opacity(0.15)
        case .critical: return .red.opacity(0.15)
        }
    }

    private var icon: String {
        switch level {
        case .normal: return "checkmark.circle"
        case .warning: return "exclamationmark.triangle"
        case .critical: return "xmark.circle"
        }
    }
}

// MARK: - Usage Section

private struct UsageSection: View {
    @ObservedObject var monitor: MemoryMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "USAGE", icon: "memorychip")

            DetailRow(
                icon: "circle.fill",
                label: "Used",
                value: monitor.formatBytes(monitor.usedBytes)
            )
            DetailRow(
                icon: "circle",
                label: "Available",
                value: monitor.formatBytes(monitor.availableBytes)
            )
            DetailRow(
                icon: "square.stack.3d.up",
                label: "Total",
                value: monitor.formatBytes(monitor.totalBytes)
            )
        }
    }
}

// MARK: - Processes Section

private struct ProcessesSection: View {
    @ObservedObject var monitor: MemoryMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "TOP PROCESSES", icon: "list.number")

            if monitor.topProcesses.isEmpty {
                Text("No data")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(monitor.topProcesses.enumerated()), id: \.offset) { _, process in
                    DetailRow(
                        icon: "app",
                        label: process.name,
                        value: monitor.formatBytes(process.bytes)
                    )
                }
            }
        }
    }
}

// MARK: - Details Section

private struct DetailsSection: View {
    @ObservedObject var monitor: MemoryMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "DETAILS", icon: "info.circle")

            DetailRow(
                icon: "lock.fill",
                label: "Wired",
                value: monitor.formatBytes(monitor.wiredBytes)
            )
            DetailRow(
                icon: "archivebox",
                label: "Compressed",
                value: monitor.formatBytes(monitor.compressedBytes)
            )
            DetailRow(
                icon: "bolt.fill",
                label: "Active",
                value: monitor.formatBytes(monitor.activeBytes)
            )
            DetailRow(
                icon: "moon.fill",
                label: "Inactive",
                value: monitor.formatBytes(monitor.inactiveBytes)
            )
            DetailRow(
                icon: "arrow.left.arrow.right",
                label: "Swap Used",
                value: monitor.formatBytes(monitor.swapUsedBytes)
            )
            DetailRow(
                icon: "arrow.down.circle",
                label: "Page Ins",
                value: formatCount(monitor.pageIns)
            )
            DetailRow(
                icon: "arrow.up.circle",
                label: "Page Outs",
                value: formatCount(monitor.pageOuts)
            )
        }
    }

    private func formatCount(_ count: UInt64) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }
}

// MARK: - Actions Section

private struct ActionsSection: View {
    @ObservedObject var monitor: MemoryMonitor

    var body: some View {
        HStack {
            Button(action: { NSApplication.shared.terminate(nil) }) {
                Text("Quit")
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q", modifiers: .command)

            Spacer()

            Text("⌘Q")
        }
    }
}

// MARK: - Reusable Components

private struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(title)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .foregroundColor(.secondary)
        .padding(.bottom, 2)
    }
}

private struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 20)

            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)

            Spacer()

            Text(value)
                .font(.subheadline.monospacedDigit())
                .foregroundColor(valueColor)
        }
    }
}

// MARK: - Preview

#Preview {
    MemoryMenuView(monitor: MemoryMonitor())
        .frame(width: 240)
}
