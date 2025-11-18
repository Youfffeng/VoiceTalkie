//
//  VoiceTalkieCoordinator.swift
//  VoiceTalkie
//
//  Created by Qoder on 11/18/25.
//

import Foundation
import AVFoundation
import Combine

/// Main coordinator that integrates all managers
@MainActor
class VoiceTalkieCoordinator: ObservableObject {
    static let shared = VoiceTalkieCoordinator()
    
    // MARK: - Published Properties
    
    @Published var isRecording = false
    @Published var isTranscribing = false
    @Published var currentText = ""
    @Published var error: String?
    
    // MARK: - Managers
    
    private let hotkeyManager = HotkeyManager.shared
    private let audioRecorder = AudioRecorder.shared
    private let whisperManager = WhisperManager.shared
    private let textInputManager = TextInputManager.shared
    private let permissionService = PermissionService.shared
    private let settings = AppSettings.shared
    
    // MARK: - State
    
    private var recordingMode: RecordingMode {
        RecordingMode(rawValue: settings.recordingMode) ?? .holdToSpeak
    }
    
    private var isToggledRecording = false
    
    private init() {
        setupHotkeyCallbacks()
    }
    
    // MARK: - Initialization
    
    func initialize() async {
        print("🚀 Initializing VoiceTalkie Coordinator...")
        
        // Check permissions
        if !permissionService.areAllPermissionsGranted() {
            print("⚠️ Not all permissions granted, requesting...")
            await permissionService.requestAllPermissions()
        }
        
        // Initialize WhisperKit
        do {
            let model = WhisperModel(rawValue: settings.selectedModel) ?? .small
            try await whisperManager.initialize(model: model)
            print("✅ WhisperKit initialized with model: \(model.rawValue)")
        } catch {
            print("❌ Failed to initialize WhisperKit: \(error)")
            self.error = error.localizedDescription
        }
        
        // Start hotkey monitoring
        hotkeyManager.startMonitoring()
        
        print("✅ VoiceTalkie Coordinator initialized")
    }
    
    // MARK: - Hotkey Setup
    
    private func setupHotkeyCallbacks() {
        hotkeyManager.onHotkeyPressed = { [weak self] in
            Task { @MainActor in
                await self?.handleHotkeyPressed()
            }
        }
        
        hotkeyManager.onHotkeyReleased = { [weak self] in
            Task { @MainActor in
                await self?.handleHotkeyReleased()
            }
        }
    }
    
    // MARK: - Hotkey Handling
    
    private func handleHotkeyPressed() async {
        print("\n🎤 [Coordinator] ========== HOTKEY PRESSED ==========")
        print("📊 [Coordinator] Current state: isRecording=\(isRecording), isTranscribing=\(isTranscribing)")
        print("🎚️ [Coordinator] Recording mode: \(recordingMode.rawValue)")
        
        switch recordingMode {
        case .holdToSpeak:
            // 在按住模式下，只在第一次按下时启动录音
            if !isRecording {
                print("🔵 [Coordinator] Mode: Hold-to-speak - Starting recording")
                await startRecording()
            } else {
                print("🔁 [Coordinator] Mode: Hold-to-speak - Already recording, ignoring repeated keydown")
            }
            
        case .clickToToggle:
            print("🔵 [Coordinator] Mode: Click-to-toggle")
            if isRecording {
                print("⏹️ [Coordinator] Already recording, stopping and transcribing")
                await stopRecordingAndTranscribe()
            } else {
                print("▶️ [Coordinator] Not recording, starting now")
                await startRecording()
                isToggledRecording = true
            }
        }
        print("🎤 [Coordinator] ========== HOTKEY PRESSED END ==========")
        print("")
    }
    
    private func handleHotkeyReleased() async {
        print("\n🎤 [Coordinator] ========== HOTKEY RELEASED ==========")
        print("📊 [Coordinator] Current state: isRecording=\(isRecording), recordingMode=\(recordingMode.rawValue)")
        
        // Only handle release in hold-to-speak mode
        if recordingMode == .holdToSpeak && isRecording {
            print("⏹️ [Coordinator] Hold-to-speak mode + is recording, stopping and transcribing")
            await stopRecordingAndTranscribe()
        } else {
            print("⚠️ [Coordinator] Ignoring release (mode=\(recordingMode.rawValue), isRecording=\(isRecording))")
        }
        print("🎤 [Coordinator] ========== HOTKEY RELEASED END ==========")
        print("")
    }
    
    // MARK: - Recording
    
    private func startRecording() async {
        print("🎬 [Coordinator] startRecording() called")
        guard !isRecording else {
            print("⚠️ [Coordinator] Already recording, ignoring")
            return
        }
        
        print("▶️ [Coordinator] Initializing recording...")
        currentText = ""
        
        // Check microphone permission before starting recording
        let authorized = await permissionService.ensureMicrophoneAuthorized()
        guard authorized else {
            print("❌ [Coordinator] Microphone not authorized, aborting startRecording")
            return
        }
        
        do {
            print("🎙️ [Coordinator] Calling audioRecorder.startRecording()")
            try await audioRecorder.startRecording()
            isRecording = true
            notifyStateChanged()
            print("✅ [Coordinator] Recording started successfully")
        } catch {
            print("❌ [Coordinator] Failed to start recording: \(error)")
            print("❌ [Coordinator] Error details: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
    }
    
    private func stopRecordingAndTranscribe() async {
        print("\n⏹️ [Coordinator] ========== STOP RECORDING & TRANSCRIBE ==========")
        guard isRecording else {
            print("⚠️ [Coordinator] Not recording, ignoring stop request")
            return
        }
        
        print("⏹️ [Coordinator] Stopping audio recorder...")
        
        // Stop recording and get audio file
        guard let audioURL = audioRecorder.stopRecording() else {
            print("❌ [Coordinator] No audio file returned from recorder")
            isRecording = false
            notifyStateChanged()
            return
        }
        
        print("📁 [Coordinator] Audio file saved at: \(audioURL.path)")
        print("📊 [Coordinator] File size: \(String(describing: try? FileManager.default.attributesOfItem(atPath: audioURL.path)[.size])) bytes")
        
        isRecording = false
        isTranscribing = true
        notifyStateChanged()
        
        // Transcribe audio
        do {
            print("🔄 [Coordinator] Starting transcription with WhisperKit...")
            print("🤖 [Coordinator] WhisperKit initialized: \(whisperManager.isInitialized)")
            print("📝 [Coordinator] Current model: \(whisperManager.currentModel.rawValue)")
            
            let result = try await whisperManager.transcribe(audioURL: audioURL)
            currentText = result.text
            
            print("✅ [Coordinator] Transcription complete!")
            print("📝 [Coordinator] Transcribed text: '\(result.text)'")
            print("📏 [Coordinator] Text length: \(result.text.count) characters")
            
            // Insert text
            if !result.text.isEmpty {
                print("⌨️ [Coordinator] Inserting text into active application...")
                insertTranscribedText(result.text)
            } else {
                print("⚠️ [Coordinator] Transcription returned empty text")
            }
            
            // Cleanup temp file
            print("🗑️ [Coordinator] Cleaning up temp audio file")
            try? FileManager.default.removeItem(at: audioURL)
            
        } catch {
            print("❌ [Coordinator] Transcription failed!")
            print("❌ [Coordinator] Error: \(error)")
            print("❌ [Coordinator] Error description: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
        
        isTranscribing = false
        isToggledRecording = false
        notifyStateChanged()
        print("⏹️ [Coordinator] ========== STOP RECORDING & TRANSCRIBE END ==========")
        print("")
    }
    
    // MARK: - Text Insertion
    
    private func insertTranscribedText(_ text: String) {
        print("⌨️ [Coordinator] insertTranscribedText() called")
        guard !text.isEmpty else {
            print("⚠️ [Coordinator] Text is empty, skipping insertion")
            return
        }
        
        let inputMethod = TextInputMethod(rawValue: settings.textInputMethod) ?? .simulate
        print("🎚️ [Coordinator] Using input method: \(inputMethod.rawValue)")
        
        // 暂停快捷键监听，避免捕获自己模拟的按键
        print("⏸️ [Coordinator] Pausing hotkey monitoring during text input")
        hotkeyManager.pauseMonitoring()
        
        // 执行文本输入
        switch inputMethod {
        case .simulate:
            print("⌨️ [Coordinator] Calling textInputManager.insertText()")
            textInputManager.insertText(text)
        case .paste:
            print("📋 [Coordinator] Calling textInputManager.insertTextViaPaste()")
            textInputManager.insertTextViaPaste(text)
        }
        
        // ⏰ 等待文本输入完全完成后再恢复监听
        // 计算所需的延迟时间：字符数 * 每字符延迟 + 额外缓冲时间
        let charCount = text.count
        let baseDelay = charCount * 10_000  // 每字符10ms
        let bufferDelay = 200_000  // 额外200ms缓冲
        let totalDelay = UInt32(baseDelay + bufferDelay)
        
        print("⏰ [Coordinator] Waiting \(Double(totalDelay)/1000.0)ms for text input to complete...")
        usleep(totalDelay)
        
        // 恢复快捷键监听
        print("▶️ [Coordinator] Resuming hotkey monitoring")
        hotkeyManager.resumeMonitoring()
        
        print("✅ [Coordinator] Text insertion completed")
    }
    
    // MARK: - Manual Control
    
    func manualStartRecording() async {
        await startRecording()
    }
    
    func manualStopRecording() async {
        await stopRecordingAndTranscribe()
    }
    
    func cancelRecording() {
        audioRecorder.cancelRecording()
        isRecording = false
        isTranscribing = false
        currentText = ""
        notifyStateChanged()
    }
    
    // MARK: - Helpers
    
    private func notifyStateChanged() {
        NotificationCenter.default.post(
            name: NSNotification.Name("VoiceTalkieRecordingStateChanged"),
            object: nil
        )
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        hotkeyManager.stopMonitoring()
        audioRecorder.cancelRecording()
        whisperManager.cleanup()
    }
}
