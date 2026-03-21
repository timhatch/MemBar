import SwiftUI
import ServiceManagement

@main
struct MemBarApp: App {
    @StateObject private var monitor = MemoryMonitor()

    init() {
        registerAsLoginItemIfNeeded()
    }

    var body: some Scene {
        MenuBarExtra {
            MemoryMenuView(monitor: monitor)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: pressureIcon)
                    .imageScale(.large) // Or .small / .medium
                    .symbolRenderingMode(.palette)
                    // .foregroundStyle(pressureColor)
            }
        }
        .menuBarExtraStyle(.window)
    }

    private var pressureIcon: String {
        switch monitor.snapshot.pressureLevel {
        case .normal: return "checkmark.circle"
        case .warning: return "exclamationmark.triangle"
        case .critical: return "xmark.circle"
        }
    }

    // private var pressureColor: Color {
    //     switch monitor.pressureLevel {
    //     case .normal: return .green
    //     case .warning: return .orange
    //     case .critical: return .red
    //     }
    // }

    private func registerAsLoginItemIfNeeded() {
        guard #available(macOS 13.0, *) else { return }

        let service = SMAppService.mainApp
        if service.status == .notRegistered || service.status == .notFound {
            try? service.register()
        }
    }
}
