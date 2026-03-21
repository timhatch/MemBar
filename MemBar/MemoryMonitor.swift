import Foundation
import IOKit.ps
import Combine

final class MemoryMonitor: ObservableObject {
    // MARK: - Memory State
    @Published var usedBytes: UInt64 = 0
    @Published var wiredBytes: UInt64 = 0
    @Published var activeBytes: UInt64 = 0
    @Published var inactiveBytes: UInt64 = 0
    @Published var compressedBytes: UInt64 = 0
    @Published var freeBytes: UInt64 = 0
    @Published var totalBytes: UInt64 = 0
    @Published var availableBytes: UInt64 = 0

    // MARK: - Swap & Paging
    @Published var swapUsedBytes: UInt64 = 0
    @Published var pageIns: UInt64 = 0
    @Published var pageOuts: UInt64 = 0

    // MARK: - Pressure
    @Published var pressureLevel: PressureLevel = .normal

    // MARK: - Top Processes
    @Published var topProcesses: [(name: String, bytes: UInt64)] = []

    // MARK: - Power State
    @Published var onACPower: Bool = true

    private var refreshTimer: Timer?
    private var runLoopSource: CFRunLoopSource?

    enum PressureLevel: String {
        case normal = "Normal"
        case warning = "Warning"
        case critical = "Critical"
    }

    init() {
        totalBytes = ProcessInfo.processInfo.physicalMemory
        registerPowerNotifications()
        startPeriodicRefresh()
        refresh()
    }

    deinit {
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .defaultMode)
        }
        refreshTimer?.invalidate()
    }

    // MARK: - Polling

    private func startPeriodicRefresh() {
        let interval = onACPower ? 5.0 : 15.0
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    private func registerPowerNotifications() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        runLoopSource = IOPSNotificationCreateRunLoopSource(
            MemoryMonitor.powerSourceChanged,
            context
        )?.takeRetainedValue()

        if let src = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .defaultMode)
        }
    }

    private static let powerSourceChanged: IOPowerSourceCallbackType = { context in
        guard let context = context else { return }
        let monitor = Unmanaged<MemoryMonitor>.fromOpaque(context).takeUnretainedValue()
        DispatchQueue.main.async {
            monitor.updatePowerState()
            monitor.startPeriodicRefresh()
            monitor.refresh()
        }
    }

    private func updatePowerState() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else { return }

        for ps in sources {
            guard let dict = IOPSGetPowerSourceDescription(snapshot, ps)?
                    .takeUnretainedValue() as? [String: Any] else { continue }
            if let state = dict[kIOPSPowerSourceStateKey as String] as? String {
                onACPower = (state == kIOPSACPowerValue)
            }
        }
    }

    // MARK: - Refresh

    func refresh() {
        readVMStats()
        readSwap()
        readTopProcesses()
        updatePowerState()
        updateComputedValues()
    }

    // MARK: - VM Statistics

    private func readVMStats() {
        var info = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let host = mach_host_self()

        let result = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(host, HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else { return }

        let pageSize = UInt64(vm_kernel_page_size)
        wiredBytes = UInt64(info.wire_count) * pageSize
        activeBytes = UInt64(info.active_count) * pageSize
        inactiveBytes = UInt64(info.inactive_count) * pageSize
        compressedBytes = UInt64(info.compressor_page_count) * pageSize
        freeBytes = UInt64(info.free_count) * pageSize
        pageIns = UInt64(info.pageins)
        pageOuts = UInt64(info.pageouts)

        // Activity Monitor formula:
        // App Memory = internal_page_count - purgeable_count
        // Memory Used = App Memory + Wired + Compressed
        let internalBytes = UInt64(info.internal_page_count) * pageSize
        let purgeableBytes = UInt64(info.purgeable_count) * pageSize
        let appMemory = internalBytes > purgeableBytes ? internalBytes - purgeableBytes : 0
        usedBytes = appMemory + wiredBytes + compressedBytes
        availableBytes = totalBytes > usedBytes ? totalBytes - usedBytes : 0
    }

    // MARK: - Swap

    private func readSwap() {
        var swapUsage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        let result = sysctlbyname("vm.swapusage", &swapUsage, &size, nil, 0)
        if result == 0 {
            swapUsedBytes = swapUsage.xsu_used
        }
    }

    // MARK: - Top Processes

    private func readTopProcesses() {
        // Step 1: Get top 5 PIDs and memory from top (sorted by memory)
        let topTask = Process()
        topTask.executableURL = URL(fileURLWithPath: "/usr/bin/top")
        topTask.arguments = ["-l", "1", "-o", "mem", "-stats", "pid,mem", "-n", "5"]
        let topPipe = Pipe()
        topTask.standardOutput = topPipe
        topTask.standardError = FileHandle.nullDevice

        do {
            try topTask.run()
            topTask.waitUntilExit()
        } catch { return }

        let topData = topPipe.fileHandleForReading.readDataToEndOfFile()
        guard let topOutput = String(data: topData, encoding: .utf8) else { return }

        let topLines = topOutput.components(separatedBy: "\n")
        guard let headerIndex = topLines.firstIndex(where: { $0.contains("PID") && $0.contains("MEM") }) else { return }

        var pidMem: [(pid: String, bytes: UInt64)] = []
        for line in topLines.dropFirst(headerIndex + 1).prefix(5) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 2 else { continue }
            let pid = String(parts[0])
            let bytes = parseMemString(String(parts[1]))
            if bytes > 0 {
                pidMem.append((pid: pid, bytes: bytes))
            }
        }

        guard !pidMem.isEmpty else { return }

        // Step 2: Get full command names from ps for those PIDs
        let pids = pidMem.map { $0.pid }.joined(separator: ",")
        let psTask = Process()
        psTask.executableURL = URL(fileURLWithPath: "/bin/ps")
        psTask.arguments = ["-o", "pid=,comm=", "-p", pids]
        let psPipe = Pipe()
        psTask.standardOutput = psPipe
        psTask.standardError = FileHandle.nullDevice

        do {
            try psTask.run()
            psTask.waitUntilExit()
        } catch { return }

        let psData = psPipe.fileHandleForReading.readDataToEndOfFile()
        guard let psOutput = String(data: psData, encoding: .utf8) else { return }

        // Build PID -> name map
        var nameMap: [String: String] = [:]
        for line in psOutput.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.split(separator: " ", maxSplits: 1)
            guard parts.count >= 2 else { continue }
            let pid = String(parts[0])
            let fullPath = String(parts[1]).trimmingCharacters(in: .whitespaces)
            let name = (fullPath as NSString).lastPathComponent
            nameMap[pid] = name
        }

        var results: [(name: String, bytes: UInt64)] = []
        for entry in pidMem {
            let name = entry.pid == "0" ? "kernel_task" : (nameMap[entry.pid] ?? "PID \(entry.pid)")
            results.append((name: name, bytes: entry.bytes))
        }

        topProcesses = results
    }

    private func parseMemString(_ str: String) -> UInt64 {
        let upper = str.uppercased()
        let numStr = upper.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        guard let value = Double(numStr) else { return 0 }

        if upper.hasSuffix("G") {
            return UInt64(value * 1_073_741_824)
        } else if upper.hasSuffix("M") {
            return UInt64(value * 1_048_576)
        } else if upper.hasSuffix("K") {
            return UInt64(value * 1024)
        } else {
            return UInt64(value)
        }
    }

    // MARK: - Computed Values

    private func updateComputedValues() {
        // Pressure level
        let usedFraction = totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) : 0
        if usedFraction > 0.90 {
            pressureLevel = .critical
        } else if usedFraction > 0.75 {
            pressureLevel = .warning
        } else {
            pressureLevel = .normal
        }

    }

    // MARK: - Formatting

    func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        return String(format: "%.2f GB", gb)
    }

    func formatBytesWhole(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        return String(format: "%.0f GB", gb)
    }

    func formatBytesShort(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        return String(format: "%.1f GB", gb)
    }
}
