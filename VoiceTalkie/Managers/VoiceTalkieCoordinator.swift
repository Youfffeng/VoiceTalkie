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
        print("🎤 Hotkey pressed")
        
        switch recordingMode {
        case .holdToSpeak:
            // Start recording on press
            await startRecording()
            
        case .clickToToggle:
            // Toggle recording
            if isRecording {
                await stopRecordingAndTranscribe()
            } else {
                await startRecording()
                isToggledRecording = true
            }
        }
    }
    
    private func handleHotkeyReleased() async {
        print("🎤 Hotkey released")
        
        // Only handle release in hold-to-speak mode
        if recordingMode == .holdToSpeak && isRecording {
            await stopRecordingAndTranscribe()
        }
    }
    
    // MARK: - Recording
    
    private func startRecording() async {
        guard !isRecording else { return }
        
        print("▶️ Starting recording...")
        currentText = ""
        
        do {
            try audioRecorder.startRecording()
            isRecording = true
            notifyStateChanged()
        } catch {
            print("❌ Failed to start recording: \(error)")
            self.error = error.localizedDescription
        }
    }
    
    private func stopRecordingAndTranscribe() async {
        guard isRecording else { return }
        
        print("⏹️ Stopping recording...")
        
        // Stop recording and get audio file
        guard let audioURL = audioRecorder.stopRecording() else {
            print("❌ No audio file")
            isRecording = false
            notifyStateChanged()
            return
        }
        
        isRecording = false
        isTranscribing = true
        notifyStateChanged()
        
        // Transcribe audio
        do {
            print("🔄 Transcribing audio...")
            let result = try await whisperManager.transcribe(audioURL: audioURL)
            currentText = result.text
            
            print("✅ Transcription complete: \(result.text)")
            
            // Insert text
            insertTranscribedText(result.text)
            
            // Cleanup temp file
            try? FileManager.default.removeItem(at: audioURL)
            
        } catch {
            print("❌ Transcription failed: \(error)")
            self.error = error.localizedDescription
        }
        
        isTranscribing = false
        isToggledRecording = false
        notifyStateChanged()
    }
    
    // MARK: - Text Insertion
    
    private func insertTranscribedText(_ text: String) {
        guard !text.isEmpty else { return }
        
        let inputMethod = TextInputMethod(rawValue: settings.textInputMethod) ?? .simulate
        
        switch inputMethod {
        case .simulate:
            textInputManager.insertText(text)
        case .paste:
            textInputManager.insertTextViaPaste(text)
        }
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
