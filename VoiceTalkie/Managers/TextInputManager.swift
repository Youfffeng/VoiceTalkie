//
//  TextInputManager.swift
//  VoiceTalkie
//
//  Created by Qoder on 11/18/25.
//

import Foundation
import AppKit
import Carbon

/// Manager for simulating text input
@MainActor
class TextInputManager {
    static let shared = TextInputManager()
    
    private init() {}
    
    // MARK: - Text Input
    
    /// Insert text at the current cursor position using CGEvent
    func insertText(_ text: String) {
        print("⌨️ [TextInputManager] insertText() called")
        print("📝 [TextInputManager] Text to insert: '\(text)' (\(text.count) characters)")
        guard !text.isEmpty else {
            print("⚠️ [TextInputManager] Text is empty, skipping")
            return
        }
        
        // Check if we have accessibility permission
        guard PermissionService.shared.checkAccessibilityPermission() else {
            print("❌ [TextInputManager] No accessibility permission")
            PermissionService.shared.promptAccessibilityPermission()
            return
        }
        print("✅ [TextInputManager] Accessibility permission granted")
        
        // Get current application
        let currentApp = NSWorkspace.shared.frontmostApplication
        print("📝 [TextInputManager] Target app: \(currentApp?.localizedName ?? "Unknown")")
        
        // Simulate typing each character
        print("🚀 [TextInputManager] Starting character-by-character insertion...")
        var charCount = 0
        for character in text {
            charCount += 1
            if character == "\n" {
                // Handle newline
                simulateKeyPress(keyCode: UInt16(kVK_Return))
            } else {
                // Handle regular character
                simulateCharacterInput(character)
            }
            
            // Small delay between characters for reliability
            usleep(10000) // 10ms
        }
        
        print("✅ [TextInputManager] Inserted \(charCount) characters successfully")
    }
    
    /// Insert text using pasteboard (alternative method)
    func insertTextViaPaste(_ text: String) {
        print("📋 [TextInputManager] insertTextViaPaste() called")
        print("📝 [TextInputManager] Text to paste: '\(text)' (\(text.count) characters)")
        guard !text.isEmpty else {
            print("⚠️ [TextInputManager] Text is empty, skipping")
            return
        }
        
        print("💾 [TextInputManager] Saving current pasteboard content")
        // Save current pasteboard content
        let pasteboard = NSPasteboard.general
        let savedContent = pasteboard.string(forType: .string)
        
        // Set new content
        print("📋 [TextInputManager] Setting text to pasteboard")
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Simulate Cmd+V
        print("⌨️ [TextInputManager] Simulating Cmd+V")
        simulatePaste()
        
        // Wait a bit for paste to complete
        usleep(100000) // 100ms
        
        // Restore original pasteboard content
        print("♻️ [TextInputManager] Restoring original pasteboard content")
        pasteboard.clearContents()
        if let savedContent = savedContent {
            pasteboard.setString(savedContent, forType: .string)
        }
        
        print("✅ [TextInputManager] Text pasted successfully")
    }
    
    // MARK: - Helper Methods
    
    private func simulateCharacterInput(_ character: Character) {
        let string = String(character)
        
        // Create key down event
        if let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) {
            keyDownEvent.keyboardSetUnicodeString(stringLength: string.utf16.count, unicodeString: Array(string.utf16))
            keyDownEvent.post(tap: .cghidEventTap)
        }
        
        // Create key up event
        if let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) {
            keyUpEvent.keyboardSetUnicodeString(stringLength: string.utf16.count, unicodeString: Array(string.utf16))
            keyUpEvent.post(tap: .cghidEventTap)
        }
    }
    
    private func simulateKeyPress(keyCode: UInt16, modifiers: CGEventFlags = []) {
        // Key down
        if let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) {
            keyDown.flags = modifiers
            keyDown.post(tap: .cghidEventTap)
        }
        
        usleep(20000) // 20ms
        
        // Key up
        if let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) {
            keyUp.flags = modifiers
            keyUp.post(tap: .cghidEventTap)
        }
    }
    
    private func simulatePaste() {
        // Simulate Cmd+V
        let cmdKey: CGEventFlags = .maskCommand
        simulateKeyPress(keyCode: UInt16(kVK_ANSI_V), modifiers: cmdKey)
    }
    
    // MARK: - Focused Application
    
    /// Get the currently focused application
    func getFocusedApplication() -> NSRunningApplication? {
        return NSWorkspace.shared.frontmostApplication
    }
    
    /// Get the currently focused window title (if accessible)
    func getFocusedWindowTitle() -> String? {
        guard PermissionService.shared.checkAccessibilityPermission() else {
            return nil
        }
        
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedApp: CFTypeRef?
        
        let result = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute as CFString, &focusedApp)
        
        guard result == .success, let appElement = focusedApp else {
            return nil
        }
        
        var focusedWindow: CFTypeRef?
        let windowResult = AXUIElementCopyAttributeValue(appElement as! AXUIElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        
        guard windowResult == .success, let windowElement = focusedWindow else {
            return nil
        }
        
        var title: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(windowElement as! AXUIElement, kAXTitleAttribute as CFString, &title)
        
        guard titleResult == .success, let titleString = title as? String else {
            return nil
        }
        
        return titleString
    }
}
