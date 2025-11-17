//
//  RecordingIndicatorWindow.swift
//  VoiceTalkie
//
//  Created by Qoder on 11/18/25.
//

import SwiftUI
import AppKit

/// Floating window that displays recording status
class RecordingIndicatorWindow: NSPanel {
    private var hostingView: NSHostingView<RecordingIndicatorView>?
    
    init() {
        // Create window with floating level
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 150),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // Configure window
        self.isFloatingPanel = true
        self.level = .floating
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Create SwiftUI view
        let contentView = RecordingIndicatorView()
        hostingView = NSHostingView(rootView: contentView)
        self.contentView = hostingView
        
        // Position window at bottom center of screen
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let windowRect = self.frame
            let x = screenRect.midX - windowRect.width / 2
            let y = screenRect.minY + 100  // 100pt from bottom
            self.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
    
    /// Show the indicator window
    func show() {
        self.orderFrontRegardless()
        self.makeKey()
        
        // Animate in
        self.animator().alphaValue = 1.0
    }
    
    /// Hide the indicator window
    func hide() {
        // Animate out
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            self.animator().alphaValue = 0.0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }
    
    /// Update window position (call when screen layout changes)
    func updatePosition() {
        guard let screen = NSScreen.main else { return }
        let screenRect = screen.visibleFrame
        let windowRect = self.frame
        let x = screenRect.midX - windowRect.width / 2
        let y = screenRect.minY + 100
        self.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
