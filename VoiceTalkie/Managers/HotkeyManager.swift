//
//  HotkeyManager.swift
//  VoiceTalkie
//
//  Created by Qoder on 11/18/25.
//

import Foundation
import Carbon
import AppKit
import Combine

/// Manager for global hotkey monitoring
@MainActor
class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()
    
    // MARK: - Published Properties
    
    @Published var isMonitoring = false
    @Published var currentHotkey: (keyCode: UInt16, modifiers: NSEvent.ModifierFlags)?
    @Published var hotkeyDisplayString: String = "Cmd+Shift+Space"
    
    // MARK: - Properties
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isTemporarilyPaused = false  // 新增：临时暂停标志
    
    // Callbacks
    var onHotkeyPressed: (() -> Void)?
    var onHotkeyReleased: (() -> Void)?
    
    private init() {
        loadSavedHotkey()
    }
    
    // MARK: - Hotkey Management
    
    /// Start monitoring for global hotkeys
    func startMonitoring() {
        print("🎯 [HotkeyManager] startMonitoring called")
        guard !isMonitoring else {
            print("⚠️ [HotkeyManager] Already monitoring, skipping")
            return
        }
        
        // Check if we have input monitoring permission
        guard PermissionService.shared.checkInputMonitoringPermission() else {
            print("❌ [HotkeyManager] No input monitoring permission")
            PermissionService.shared.promptInputMonitoringPermission()
            return
        }
        print("✅ [HotkeyManager] Input monitoring permission granted")
        
        // Create event tap
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                
                Task { @MainActor in
                    if manager.handleEvent(type: type, event: event) {
                        // Consume the event - return nil wrapped
                        // But we can't return nil here, just pass through
                    }
                }
                
                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("❌ Failed to create event tap")
            return
        }
        
        self.eventTap = eventTap
        
        // Create run loop source
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        
        guard let runLoopSource = runLoopSource else {
            print("❌ Failed to create run loop source")
            return
        }
        
        // Add to run loop
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        
        // Enable event tap
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        isMonitoring = true
        let hotkeyDesc = KeyCodeMapper.hotkeyDescription(keyCode: currentHotkey?.keyCode ?? 0, modifiers: currentHotkey?.modifiers ?? [])
        print("✅ [HotkeyManager] Hotkey monitoring started successfully")
        print("🎹 [HotkeyManager] Monitoring hotkey: \(hotkeyDesc)")
    }
    
    /// Stop monitoring for global hotkeys
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        
        eventTap = nil
        runLoopSource = nil
        isMonitoring = false
        isTemporarilyPaused = false
        
        print("✅ Hotkey monitoring stopped")
    }
    
    /// 临时暂停监听（用于文本输入期间）
    func pauseMonitoring() {
        print("⏸️ [HotkeyManager] Pausing monitoring temporarily")
        isTemporarilyPaused = true
    }
    
    /// 恢复监听
    func resumeMonitoring() {
        print("▶️ [HotkeyManager] Resuming monitoring")
        isTemporarilyPaused = false
    }
    
    /// Set a new hotkey
    func setHotkey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        currentHotkey = (keyCode, modifiers)
        updateDisplayString()
        saveHotkey()
        print("✅ Hotkey set: \(KeyCodeMapper.hotkeyDescription(keyCode: keyCode, modifiers: modifiers))")
    }
    
    // MARK: - Event Handling
    
    private func handleEvent(type: CGEventType, event: CGEvent) -> Bool {
        // 如果临时暂停，忽略所有事件
        guard !isTemporarilyPaused else {
            return false
        }
        
        guard let (hotkeyCode, hotkeyModifiers) = currentHotkey else { 
            print("⚠️ [HotkeyManager] No hotkey configured")
            return false 
        }
        
        // 获取当前的热键模式
        let settings = AppSettings.shared
        let isSingleKeyMode = settings.hotkeyMode == HotkeyMode.singleKey.rawValue
        
        switch type {
        case .keyDown:
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags
            let modifiers = KeyCodeMapper.eventFlagsToModifiers(flags)
            
            let keyDesc = KeyCodeMapper.keyCodeToString(keyCode)
            let modDesc = KeyCodeMapper.modifiersToString(modifiers)
            print("⌨️ [HotkeyManager] KeyDown detected: \(modDesc)\(keyDesc)")
            
            // 根据模式匹配热键
            let isMatch: Bool
            if isSingleKeyMode {
                // 单键模式：只匹配键码，忽略修饰键
                isMatch = (keyCode == hotkeyCode)
                if isMatch {
                    print("🎯 [HotkeyManager] Single-key hotkey MATCHED (\(keyDesc))")
                }
            } else {
                // 组合键模式：键码和修饰键都必须匹配
                isMatch = (keyCode == hotkeyCode && modifiers == hotkeyModifiers)
                if isMatch {
                    print("🎯 [HotkeyManager] Combination hotkey MATCHED (\(modDesc)\(keyDesc))")
                }
            }
            
            if isMatch {
                print("🎯 [HotkeyManager] Hotkey MATCHED! Triggering onHotkeyPressed")
                onHotkeyPressed?()
                return true  // Consume the event
            } else {
                print("❌ [HotkeyManager] Key does not match hotkey (expected: \(KeyCodeMapper.hotkeyDescription(keyCode: hotkeyCode, modifiers: hotkeyModifiers)))")
            }
            
        case .keyUp:
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let keyDesc = KeyCodeMapper.keyCodeToString(keyCode)
            print("⌨️ [HotkeyManager] KeyUp detected: \(keyDesc)")
            
            if keyCode == hotkeyCode {
                print("🎯 [HotkeyManager] Hotkey RELEASED! Triggering onHotkeyReleased")
                onHotkeyReleased?()
                return true  // Consume the event
            }
            
        case .flagsChanged:
            // Handle modifier key release for hold-to-speak mode
            let flags = event.flags
            if let (_, hotkeyMods) = currentHotkey {
                let currentMods = KeyCodeMapper.eventFlagsToModifiers(flags)
                
                // Check if hotkey modifiers were released
                if !currentMods.contains(hotkeyMods) {
                    // Modifiers released, might need to trigger release callback
                    // This is handled by keyUp event
                }
            }
            
        default:
            break
        }
        
        return false
    }
    
    // MARK: - Persistence
    
    private func saveHotkey() {
        guard let (keyCode, modifiers) = currentHotkey else { return }
        
        UserDefaults.standard.set(Int(keyCode), forKey: "hotkeyKeyCode")
        UserDefaults.standard.set(modifiers.rawValue, forKey: "hotkeyModifiers")
    }
    
    private func loadSavedHotkey() {
        let keyCode = UserDefaults.standard.integer(forKey: "hotkeyKeyCode")
        let modifiersRaw = UserDefaults.standard.integer(forKey: "hotkeyModifiers")
        
        if keyCode != 0 {
            let modifiers = NSEvent.ModifierFlags(rawValue: UInt(modifiersRaw))
            currentHotkey = (UInt16(keyCode), modifiers)
        } else {
            // Default hotkey: Cmd + Shift + Space
            currentHotkey = (UInt16(kVK_Space), [.command, .shift])
        }
        
        updateDisplayString()
    }
    
    private func updateDisplayString() {
        guard let (keyCode, modifiers) = currentHotkey else {
            hotkeyDisplayString = "Cmd+Shift+Space"
            return
        }
        hotkeyDisplayString = KeyCodeMapper.hotkeyDescription(keyCode: keyCode, modifiers: modifiers)
    }
}
