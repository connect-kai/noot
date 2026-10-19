import AppKit
import ApplicationServices

/// Owns the permission-gated keyboard monitor. Checking trust must never prompt.
final class GlobalDoubleTapMonitor {
    typealias Handler = (NSEvent) -> Void

    private let isTrusted: () -> Bool
    private let addMonitor: (@escaping Handler) -> Any?
    private let removeMonitor: (Any) -> Void
    private var monitor: Any?
    private var attemptedInstallation = false

    init(
        isTrusted: @escaping () -> Bool = { AXIsProcessTrusted() },
        addMonitor: @escaping (@escaping Handler) -> Any? = {
            NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown], handler: $0)
        },
        removeMonitor: @escaping (Any) -> Void = { NSEvent.removeMonitor($0) }
    ) {
        self.isTrusted = isTrusted
        self.addMonitor = addMonitor
        self.removeMonitor = removeMonitor
    }

    func refresh(enabled: Bool, handler: @escaping Handler) {
        // Registering a keyboard monitor without trust can itself trigger macOS's
        // access dialog, even when no explicit AX permission prompt was requested.
        guard enabled, isTrusted() else {
            stop()
            return
        }
        guard !attemptedInstallation else { return }
        attemptedInstallation = true
        monitor = addMonitor(handler)
    }

    func stop() {
        if let monitor { removeMonitor(monitor) }
        monitor = nil
        attemptedInstallation = false
    }

    deinit { stop() }
}
