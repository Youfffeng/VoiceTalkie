//
//  SettingsView.swift
//  VoiceTalkie
//
//  Created by Qoder on 11/18/25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var whisperManager = WhisperManager.shared
    @ObservedObject var hotkeyManager = HotkeyManager.shared
    
    @State private var isRecordingHotkey = false
    
    var body: some View {
        Form {
            // WhisperKit Model Section
            modelSection
            
            // Recording Mode Section
            recordingModeSection
            
            // Hotkey Section
            hotkeySection
            
            // Language Section
            languageSection
            
            // Text Input Method Section
            textInputMethodSection
            
            // Auto Input Section
            autoInputSection
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 600)
    }
    
    // MARK: - Model Section
    
    private var modelSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Picker("whisper_model", selection: $settings.selectedModel) {
                    ForEach(WhisperModel.allCases, id: \.self) { model in
                        VStack(alignment: .leading) {
                            Text(model.rawValue.capitalized)
                            Text(modelDescription(for: model))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .tag(model.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
                
                if whisperManager.isDownloading {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("downloading_model")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ProgressView(value: whisperManager.downloadProgress)
                            .progressViewStyle(.linear)
                    }
                }
                
                if !whisperManager.isInitialized {
                    Button("download_and_initialize") {
                        Task {
                            try? await whisperManager.initialize()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        } header: {
            Text("recognition_model")
        } footer: {
            Text("model_footer_description")
                .font(.caption)
        }
    }
    
    // MARK: - Recording Mode Section
    
    private var recordingModeSection: some View {
        Section {
            Picker("recording_mode", selection: $settings.recordingMode) {
                Text("hold_to_speak")
                    .tag("hold")
                Text("click_to_toggle")
                    .tag("toggle")
            }
            .pickerStyle(.radioGroup)
        } header: {
            Text("recording_settings")
        } footer: {
            Text(recordingModeFooter)
                .font(.caption)
        }
    }
    
    // MARK: - Hotkey Section
    
    private var hotkeySection: some View {
        Section {
            HStack {
                Text("global_hotkey")
                
                Spacer()
                
                Button(action: {
                    isRecordingHotkey.toggle()
                }) {
                    Text(hotkeyDisplayText)
                        .frame(minWidth: 150)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isRecordingHotkey ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            if isRecordingHotkey {
                Text("press_hotkey_hint")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("hotkey_settings")
        }
    }
    
    // MARK: - Language Section
    
    private var languageSection: some View {
        Section {
            Picker("recognition_language", selection: $settings.recognitionLanguage) {
                Text("auto_detect").tag("auto")
                Text("chinese").tag("zh")
                Text("english").tag("en")
                Text("japanese").tag("ja")
                Text("korean").tag("ko")
            }
        } header: {
            Text("language_settings")
        }
    }
    
    // MARK: - Text Input Method Section
    
    private var textInputMethodSection: some View {
        Section {
            Picker("input_method", selection: $settings.textInputMethod) {
                VStack(alignment: .leading) {
                    Text("cg_event_simulate")
                    Text("input_method_simulate_description")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .tag("simulate")
                
                VStack(alignment: .leading) {
                    Text("clipboard_paste")
                    Text("input_method_paste_description")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .tag("paste")
            }
            .pickerStyle(.radioGroup)
        } header: {
            Text("text_input_settings")
        }
    }
    
    // MARK: - Auto Input Section
    
    private var autoInputSection: some View {
        Section {
            Toggle("auto_input_after_recognition", isOn: $settings.autoInputEnabled)
            
            if !settings.autoInputEnabled {
                Text("auto_input_disabled_hint")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("advanced_settings")
        }
    }
    
    // MARK: - Helpers
    
    private func modelDescription(for model: WhisperModel) -> String {
        switch model {
        case .tiny:
            return "~75MB, 快速但精度较低"
        case .base:
            return "~145MB, 平衡速度与精度"
        case .small:
            return "~245MB, 推荐使用"
        case .medium:
            return "~769MB, 高精度但较慢"
        }
    }
    
    private var recordingModeFooter: String {
        if settings.recordingMode == "hold" {
            return "按住快捷键时录音，松开后自动识别"
        } else {
            return "按一次开始录音，再按一次停止并识别"
        }
    }
    
    private var hotkeyDisplayText: String {
        if isRecordingHotkey {
            return "等待按键..."
        } else if settings.hotkeyKeyCode != 0 {
            return hotkeyManager.hotkeyDisplayString
        } else {
            return "Cmd+Shift+Space (默认)"
        }
    }
}

#Preview {
    SettingsView()
}
