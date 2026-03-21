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
        .onAppear { monitor.popoverVisible = true }
        .onDisappear { monitor.popoverVisible = false }
    }
}

// MARK: - Hero Section

private struct HeroSection: View {
    @ObservedObject var monitor: MemoryMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(usedGBText)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .monospacedDigit()
                    Text("GB")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                }

                Spacer()

                PressureBadge(level: monitor.snapshot.pressureLevel)
            }
        }
    }

    private var usedGBText: String {
        let gb = Double(monitor.snapshot.usedBytes) / 1_073_741_824
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
                .fontWeight(.bold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .foregroundColor(.white)
        .background(backgroundColor)
        .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch level {
        case .normal:   return .green   
        case .warning:  return .orange  
        case .critical: return .red     
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
                value: monitor.formatBytes(monitor.snapshot.usedBytes)
            )
            DetailRow(
                icon: "circle",
                label: "Available",
                value: monitor.formatBytes(monitor.snapshot.availableBytes)
            )
            DetailRow(
                icon: "square.stack.3d.up",
                label: "Total",
                value: monitor.formatBytes(monitor.snapshot.totalBytes)
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

            if monitor.snapshot.topProcesses.isEmpty {
                Text("No data")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(monitor.snapshot.topProcesses.enumerated()), id: \.offset) { _, process in
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
                value: monitor.formatBytes(monitor.snapshot.wiredBytes)
            )
            DetailRow(
                icon: "archivebox",
                label: "Compressed",
                value: monitor.formatBytes(monitor.snapshot.compressedBytes)
            )
            DetailRow(
                icon: "bolt.fill",
                label: "Active",
                value: monitor.formatBytes(monitor.snapshot.activeBytes)
            )
            DetailRow(
                icon: "moon.fill",
                label: "Inactive",
                value: monitor.formatBytes(monitor.snapshot.inactiveBytes)
            )
            DetailRow(
                icon: "arrow.left.arrow.right",
                label: "Swap Used",
                value: monitor.formatBytes(monitor.snapshot.swapUsedBytes)
            )
            DetailRow(
                icon: "arrow.down.circle",
                label: "Page Ins",
                value: formatCount(monitor.snapshot.pageIns)
            )
            DetailRow(
                icon: "arrow.up.circle",
                label: "Page Outs",
                value: formatCount(monitor.snapshot.pageOuts)
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
