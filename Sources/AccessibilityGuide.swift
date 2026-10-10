import AppKit
import ApplicationServices
import SwiftUI

@MainActor
final class AccessibilityGuideWindowController: NSWindowController {
    init(onClose: @escaping () -> Void) {
        let root = AccessibilityGuideView(onClose: onClose)
        let hosting = NSHostingView(rootView: root)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 390),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Enable Noot Shortcuts"
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.contentView = hosting
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func present() {
        guard let window else { return }
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }

    func dismiss() {
        window?.orderOut(nil)
        window?.resignKey()
    }
}

private struct AccessibilityGuideView: View {
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 64, height: 64)
            Text("Enable global shortcuts")
                .font(.title2.weight(.semibold))
            Text("macOS requires Accessibility permission for Noot to detect ⌥⌥ outside its own window.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 410)
            HStack(spacing: 12) {
                Text("1")
                    .font(.headline).frame(width: 26, height: 26)
                    .background(Circle().fill(.secondary.opacity(0.18)))
                Button("Open Accessibility Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility")!)
                }
            }
            HStack(spacing: 12) {
                Text("2")
                    .font(.headline).frame(width: 26, height: 26)
                    .background(Circle().fill(.secondary.opacity(0.18)))
                Text("Drag this Noot icon into the list, then turn it on")
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable().frame(width: 28, height: 28)
                    .onDrag {
                        NSItemProvider(object: NSURL(fileURLWithPath: Bundle.main.bundlePath))
                    }
                    .help("Drag Noot to the Accessibility list")
            }
            Text("You can use ⌥⌘N without this permission.")
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Done", action: onClose)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
