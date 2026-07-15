import AppKit
import SwiftUI

/// A Spotlight-style floating panel (nonactivating). Closes on ESC.
final class FloatingPanel: NSPanel {
    init(store: SkillStore) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 420),
            styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        title = "Skill Cast"
        isFloatingPanel = true
        level = .floating
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
        contentView = NSHostingView(rootView: SkillListView(store: store, panel: self))
    }

    override var canBecomeKey: Bool { true }

    func show() {
        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            let x = f.midX - frame.width / 2
            let y = f.maxY - f.height * 0.2 - frame.height
            setFrameOrigin(NSPoint(x: x, y: y))
        }
        makeKeyAndOrderFront(nil)
    }

    override func cancelOperation(_ sender: Any?) {
        close()
    }
}
