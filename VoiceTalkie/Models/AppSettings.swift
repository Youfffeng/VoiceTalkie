//
//  AppSettings.swift
//  VoiceTalkie
//
//  Created by Qoder on 11/18/25.
//

import Foundation
import SwiftUI
import Combine

/// Application settings data model
class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    // MARK: - Whisper Model Settings
    
    @AppStorage("selectedWhisperModel") 
    var selectedModel: String = WhisperModel.small.rawValue
    
    @AppStorage("autoDownloadModel") 
    var autoDownloadModel: Bool = false
    
    @AppStorage("whisperPrompt")
    var whisperPrompt: String = ""
    
    // MARK: - Audio Input Settings
    
    @AppStorage("selectedAudioInputDevice")
    var selectedAudioInputDeviceID: String = "" // 空表示使用系统默认设备
    
    // MARK: - Recording Mode Settings
    
    @AppStorage("recordingMode") 
    var recordingMode: String = RecordingMode.holdToSpeak.rawValue
    
    @AppStorage("enableVAD") 
    var enableVAD: Bool = false
    
    @AppStorage("vadThreshold") 
    var vadThreshold: Double = 0.5
    
    // MARK: - Language Settings
    
    @AppStorage("recognitionLanguage") 
    var recognitionLanguage: String = "auto"
    
    @AppStorage("preferredLanguages") 
    var preferredLanguagesData: Data = Data()
    
    var preferredLanguages: [String] {
        get {
            (try? JSONDecoder().decode([String].self, from: preferredLanguagesData)) ?? ["zh-CN", "en-US"]
        }
        set {
            preferredLanguagesData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }
    
    // MARK: - Hotkey Settings
    
    @AppStorage("hotkeyMode")
    var hotkeyMode: String = HotkeyMode.combination.rawValue
    
    @AppStorage("hotkeyModifiers") 
    var hotkeyModifiers: Int = 0
    
    @AppStorage("hotkeyKeyCode") 
    var hotkeyKeyCode: Int = 0
    
    @AppStorage("hotkeyEnabled") 
    var hotkeyEnabled: Bool = true
    
    // MARK: - Text Input Settings
    
    @AppStorage("textInputMethod") 
    var textInputMethod: String = TextInputMethod.simulate.rawValue
    
    @AppStorage("autoInputEnabled")
    var autoInputEnabled: Bool = true
    
    @AppStorage("autoCorrection") 
    var autoCorrection: Bool = true
    
    @AppStorage("addPunctuation") 
    var addPunctuation: Bool = true
    
    // MARK: - UI Settings
    
    @AppStorage("showRecordingIndicator") 
    var showRecordingIndicator: Bool = true
    
    @AppStorage("showRealtimeTranscription") 
    var showRealtimeTranscription: Bool = true
    
    @AppStorage("menuBarIconStyle") 
    var menuBarIconStyle: String = "mic"
    
    // MARK: - History Settings
    
    @AppStorage("saveHistory") 
    var saveHistory: Bool = true
    
    @AppStorage("historyLimit") 
    var historyLimit: Int = 100
    
    @AppStorage("autoDeleteHistory") 
    var autoDeleteHistory: Bool = false
    
    @AppStorage("historyRetentionDays") 
    var historyRetentionDays: Int = 30
    
    // MARK: - Privacy Settings
    
    @AppStorage("sendAnonymousUsageData") 
    var sendAnonymousUsageData: Bool = false
    
    // MARK: - Advanced Settings
    
    @AppStorage("logLevel") 
    var logLevel: String = "info"
    
    @AppStorage("maxRecordingDuration") 
    var maxRecordingDuration: Double = 300.0  // 5 minutes
    
    @AppStorage("audioQuality") 
    var audioQuality: String = AudioQuality.high.rawValue
    
    private init() {}
    
    // MARK: - Helper Methods
    
    func reset() {
        selectedModel = WhisperModel.small.rawValue
        recordingMode = RecordingMode.holdToSpeak.rawValue
        recognitionLanguage = "auto"
        hotkeyEnabled = true
        textInputMethod = TextInputMethod.simulate.rawValue
        autoCorrection = true
        addPunctuation = true
        showRecordingIndicator = true
        showRealtimeTranscription = true
        saveHistory = true
        historyLimit = 100
    }
}

// MARK: - Recording Mode

enum RecordingMode: String, CaseIterable, Identifiable {
    case holdToSpeak = "hold"
    case clickToToggle = "toggle"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .holdToSpeak:
            return NSLocalizedString("recording_mode.hold", comment: "Hold to Speak")
        case .clickToToggle:
            return NSLocalizedString("recording_mode.toggle", comment: "Click to Toggle")
        }
    }
    
    var description: String {
        switch self {
        case .holdToSpeak:
            return NSLocalizedString("recording_mode.hold.description", comment: "Press and hold hotkey to record")
        case .clickToToggle:
            return NSLocalizedString("recording_mode.toggle.description", comment: "Press once to start, press again to stop")
        }
    }
}

// MARK: - Text Input Method

enum TextInputMethod: String, CaseIterable, Identifiable {
    case simulate = "simulate"
    case paste = "paste"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .simulate:
            return NSLocalizedString("input_method.simulate", comment: "Simulate Typing")
        case .paste:
            return NSLocalizedString("input_method.paste", comment: "Paste Text")
        }
    }
}

// MARK: - Audio Quality

enum AudioQuality: String, CaseIterable, Identifiable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .low: return NSLocalizedString("audio.quality.low", comment: "Low")
        case .medium: return NSLocalizedString("audio.quality.medium", comment: "Medium")
        case .high: return NSLocalizedString("audio.quality.high", comment: "High")
        }
    }
    
    var sampleRate: Double {
        switch self {
        case .low: return 16000
        case .medium: return 24000
        case .high: return 48000
        }
    }
}

// MARK: - Hotkey Mode

enum HotkeyMode: String, CaseIterable, Identifiable {
    case singleKey = "single"
    case combination = "combination"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .singleKey:
            return "单键模式"
        case .combination:
            return "组合键模式"
        }
    }
    
    var description: String {
        switch self {
        case .singleKey:
            return "使用单个按键作为快捷键（推荐使用功能键如 F13-F19）"
        case .combination:
            return "使用组合键作为快捷键（如 Cmd+Shift+Space）"
        }
    }
}
