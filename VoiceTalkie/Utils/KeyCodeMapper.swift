//
//  KeyCodeMapper.swift
//  VoiceTalkie
//
//  Created by Qoder on 11/18/25.
//

import Foundation
import Carbon
import AppKit

/// Utility for mapping key codes and modifiers
struct KeyCodeMapper {
    
    // MARK: - Modifier Flags
    
    static func eventFlagsToModifiers(_ flags: CGEventFlags) -> NSEvent.ModifierFlags {
        var modifiers: NSEvent.ModifierFlags = []
        
        if flags.contains(.maskCommand) {
            modifiers.insert(.command)
        }
        if flags.contains(.maskControl) {
            modifiers.insert(.control)
        }
        if flags.contains(.maskAlternate) {
            modifiers.insert(.option)
        }
        if flags.contains(.maskShift) {
            modifiers.insert(.shift)
        }
        
        return modifiers
    }
    
    static func modifiersToEventFlags(_ modifiers: NSEvent.ModifierFlags) -> CGEventFlags {
        var flags: CGEventFlags = []
        
        if modifiers.contains(.command) {
            flags.insert(.maskCommand)
        }
        if modifiers.contains(.control) {
            flags.insert(.maskControl)
        }
        if modifiers.contains(.option) {
            flags.insert(.maskAlternate)
        }
        if modifiers.contains(.shift) {
            flags.insert(.maskShift)
        }
        
        return flags
    }
    
    // MARK: - Key Code Mapping
    
    static func keyCodeToString(_ keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Delete: return "Delete"
        case kVK_Escape: return "Escape"
        
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        
        default: return "Unknown"
        }
    }
    
    static func modifiersToString(_ modifiers: NSEvent.ModifierFlags) -> String {
        var components: [String] = []
        
        if modifiers.contains(.control) {
            components.append("⌃")
        }
        if modifiers.contains(.option) {
            components.append("⌥")
        }
        if modifiers.contains(.shift) {
            components.append("⇧")
        }
        if modifiers.contains(.command) {
            components.append("⌘")
        }
        
        return components.joined()
    }
    
    static func hotkeyDescription(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String {
        let modifierString = modifiersToString(modifiers)
        let keyString = keyCodeToString(keyCode)
        return modifierString + keyString
    }
}
