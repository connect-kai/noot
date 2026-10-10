import AppKit
import SwiftUI

extension NSAppearance {
    var isDark: Bool { bestMatch(from: [.darkAqua, .aqua]) == .darkAqua }
}
extension NSColor {
    static func srgbInk(_ value: CGFloat, alpha: CGFloat) -> NSColor {
        NSColor(srgbRed: value, green: value, blue: value, alpha: alpha)
    }
}

struct GlassEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        if #available(macOS 26, *) { return NSGlassEffectView() }
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ view: NSView, context: Context) {}
}
extension View {
    @ViewBuilder func frosted(in shape: some Shape) -> some View {
        if #available(macOS 26, *) {
            glassEffect(.regular.interactive(), in: shape)
        } else { background(.regularMaterial, in: shape) }
    }
    func tooltip(_ text: String?, alignment: HorizontalAlignment = .center) -> some View {
        help(text ?? "")
    }
    func overflowFade() -> some View { self }
}
struct BarButton<Label: View>: View {
    var isSelected = false
    var isCompact = false
    let action: () -> Void
    @ViewBuilder let label: Label
    @State private var hovered = false
    var body: some View {
        Button(action: action) {
            label.padding(.horizontal, isCompact ? Theme.Spacing.sm : Theme.Spacing.md)
                .frame(height: Theme.Size.barButtonHeight)
                .contentShape(Capsule())
                .background(Capsule().fill(isSelected ? Theme.Colors.selection : hovered ? Theme.Colors.rowHover : .clear))
        }.buttonStyle(.plain).onHover { hovered = $0 }
    }
}
struct KeyCapChip: View {
    enum Style { case outline }
    let text: String
    var style: Style = .outline
    var body: some View {
        Text(text).font(.caption).frame(minWidth: 18, minHeight: 18)
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.Colors.border))
    }
}
protocol InjectableTextView: AnyObject {}
