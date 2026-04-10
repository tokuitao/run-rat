import Darwin.Mach
import os

final class CPUUsageMonitor {
    private var previousTicks: [UInt64]?
    private var previousSamples: [Double] = []
    private let sampleWindow = 5

    func sampleUsage() -> Double {
        var loadInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride
        )

        let result = withUnsafeMutablePointer(to: &loadInfo) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, reboundPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            os_log("RunRat: CPU sampling failed (error: %d)", log: .default, type: .debug, result)
            return previousSamples.isEmpty ? 0.1 : previousSamples.last!
        }

        let currentTicks: [UInt64] = [
            UInt64(loadInfo.cpu_ticks.0),
            UInt64(loadInfo.cpu_ticks.1),
            UInt64(loadInfo.cpu_ticks.2),
            UInt64(loadInfo.cpu_ticks.3),
        ]

        guard let previousTicks else {
            self.previousTicks = currentTicks
            let defaultSample = 0.1
            previousSamples.append(defaultSample)
            return defaultSample
        }

        self.previousTicks = currentTicks

        let deltas = zip(currentTicks, previousTicks).map { current, previous in
            current >= previous ? current - previous : 0
        }

        let totalDelta = deltas.reduce(0, +)
        guard totalDelta > 0 else {
            return previousSamples.isEmpty ? 0.1 : previousSamples.last!
        }

        let idleDelta = deltas[Int(CPU_STATE_IDLE)]
        let usage = Double(totalDelta - idleDelta) / Double(totalDelta)
        let clampedUsage = min(max(usage, 0), 1)

        previousSamples.append(clampedUsage)
        if previousSamples.count > sampleWindow {
            previousSamples.removeFirst()
        }

        return previousSamples.reduce(0, +) / Double(previousSamples.count)
    }
}
