//
//  SettingsView.swift
//  VoiceTalkie
//
//  Created by Qoder on 11/18/25.
//

import SwiftUI

struct SettingsView: View {
    // 对于单例对象，应使用 @ObservedObject 而不是 @StateObject
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var whisperManager = WhisperManager.shared
    @ObservedObject var hotkeyManager = HotkeyManager.shared
    @ObservedObject var audioRecorder = AudioRecorder.shared
    
    @State private var isRecordingHotkey = false
    
    var body: some View {
        Form {
            // 音频输入设备选择
            audioInputSection
            
            // WhisperKit Model Section
            modelSection
            
            // Prompt Section - 新增提示词设置
            promptSection
            
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
        .frame(width: 500, height: 650)
        .onAppear {
            // 刷新设备列表
            audioRecorder.refreshAvailableDevices()
        }
        .onDisappear {
            // 窗口关闭时停止所有更新，避免 Metal 渲染错误
            isRecordingHotkey = false
            
            // 强制在主线程执行清理
            DispatchQueue.main.async {
                print("🧹 [SettingsView] onDisappear - 视图已销毁")
            }
        }
    }
    
    // MARK: - Model Section
    
    // MARK: - Audio Input Section
    
    private var audioInputSection: some View {
        Section {
            Picker("输入设备", selection: $settings.selectedAudioInputDeviceID) {
                // 系统默认选项
                Text("🎵 系统默认")
                    .tag("")
                
                // 可用设备列表
                ForEach(audioRecorder.availableInputDevices) { device in
                    HStack {
                        Text(device.name)
                        if device.isDefault {
                            Text("(默认)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tag(device.id)
                }
            }
            
            Button("🔄 刷新设备列表") {
                audioRecorder.refreshAvailableDevices()
            }
        } header: {
            Text("🎤 麦克风设置")
        } footer: {
            Text("选择用于录音的麦克风设备。选择“系统默认”将使用 macOS 系统设置中的默认输入设备。")
                .font(.caption)
        }
    }
    
    private var modelSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Picker("whisper_model", selection: $settings.selectedModel) {
                    ForEach(WhisperModel.allCases, id: \.self) { model in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(model.rawValue.capitalized)
                                Text(modelDescription(for: model))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // 显示本地状态
                            if whisperManager.isModelAvailableLocally(model) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                    Text("本地")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                }
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.down.circle")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    Text("需下载")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }
                            }
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
            VStack(alignment: .leading, spacing: 4) {
                Text("model_footer_description")
                    .font(.caption)
                
                if let selectedModel = WhisperModel(rawValue: settings.selectedModel),
                   whisperManager.isModelAvailableLocally(selectedModel) {
                    Text("✅ 当前模型已在本地，无需下载")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("⚠️ 首次使用该模型需要从网络下载")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
    }
    
    // MARK: - Prompt Section
    
    private var promptSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("提示词内容")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextEditor(text: $settings.whisperPrompt)
                    .font(.system(size: 12))
                    .frame(height: 60)
                    .padding(4)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                
                if settings.whisperPrompt.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("✏️ 提示词示例")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        Text("技术领域：这是一段关于编程技术的讲座，会提到 API、服务器、数据库等术语。")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("日常对话：日常对话，包含问候、感谢、告别等礼貌用语。")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                } else {
                    HStack {
                        Text("当前字符数: \(settings.whisperPrompt.count)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("清空") {
                            settings.whisperPrompt = ""
                        }
                        .font(.caption2)
                        .buttonStyle(.plain)
                        .foregroundColor(.blue)
                    }
                }
            }
        } header: {
            Text("📝 Whisper 提示词设置")
        } footer: {
            Text("""
            提示词可以帮助 Whisper 模型更准确地识别特定领域的内容。
            
            🎯 正确用法：
            • 使用完整的句子描述音频上下文
            • 例如："这是一段关于编程技术的讲座，会提到 API、服务器、数据库等术语。"
            • 或："日常对话，包含问候、感谢、告别等礼貌用语。"
            
            ⚠️ 注意：
            • 提示词限制为 224 个 token（约100字）
            • 不要只列举关键词，应该组成完整句子
            """)
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
            // 热键模式选择
            Picker("热键模式", selection: $settings.hotkeyMode) {
                ForEach(HotkeyMode.allCases) { mode in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(mode.displayName)
                        Text(mode.description)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .tag(mode.rawValue)
                }
            }
            .pickerStyle(.radioGroup)
            
            Divider()
            
            // 热键设置
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
                if settings.hotkeyMode == HotkeyMode.singleKey.rawValue {
                    Text("请按下你想要设置的单键（推荐使用 F13-F19 等功能键）")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("press_hotkey_hint")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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
        case .largeV3:
            return "~1.5GB, 最佳精度，较慢"
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
