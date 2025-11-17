//
//  WhisperManager.swift
//  VoiceTalkie
//
//  Created by Qoder on 11/18/25.
//

import Foundation
import AVFoundation
import WhisperKit
import Combine

/// Manager for WhisperKit speech recognition
@MainActor
class WhisperManager: ObservableObject {
    static let shared = WhisperManager()
    
    // MARK: - Published Properties
    
    @Published var isInitialized = false
    @Published var isTranscribing = false
    @Published var currentModel: WhisperModel = .small
    @Published var downloadProgress: Double = 0.0
    @Published var isDownloadingModel = false
    @Published var transcriptionText = ""
    @Published var error: WhisperError?
    
    // MARK: - Private Properties
    
    private var whisperKit: WhisperKit?
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    
    // MARK: - Initialization
    
    private init() {
        // Load saved model preference
        if let savedModel = UserDefaults.standard.string(forKey: "selectedWhisperModel"),
           let model = WhisperModel(rawValue: savedModel) {
            currentModel = model
        }
    }
    
    // MARK: - Model Management
    
    /// Initialize WhisperKit with specified model
    func initialize(model: WhisperModel? = nil) async throws {
        let modelToUse = model ?? currentModel
        
        guard !isInitialized else {
            print("WhisperKit already initialized")
            return
        }
        
        isDownloadingModel = true
        downloadProgress = 0.0
        
        do {
            whisperKit = try await WhisperKit(
                model: modelToUse.rawValue,
                downloadProgress: { progress in
                    Task { @MainActor in
                        self.downloadProgress = progress
                    }
                }
            )
            
            isInitialized = true
            currentModel = modelToUse
            isDownloadingModel = false
            
            // Save model preference
            UserDefaults.standard.set(modelToUse.rawValue, forKey: "selectedWhisperModel")
            
            print("✅ WhisperKit initialized with model: \(modelToUse.rawValue)")
            
        } catch {
            isDownloadingModel = false
            self.error = .initializationFailed(error.localizedDescription)
            throw error
        }
    }
    
    /// Switch to a different model
    func switchModel(to model: WhisperModel) async throws {
        guard model != currentModel else { return }
        
        // Reset current instance
        whisperKit = nil
        isInitialized = false
        
        // Initialize with new model
        try await initialize(model: model)
    }
    
    // MARK: - Transcription
    
    /// Transcribe audio from a file URL
    func transcribe(audioURL: URL) async throws -> TranscriptionResult {
        guard isInitialized else {
            throw WhisperError.notInitialized
        }
        
        guard !isTranscribing else {
            throw WhisperError.alreadyTranscribing
        }
        
        isTranscribing = true
        transcriptionText = ""
        
        do {
            let result = try await whisperKit?.transcribe(audioPath: audioURL.path)
            let text = result?.text ?? ""
            
            let transcriptionResult = TranscriptionResult(
                text: text,
                confidence: nil,
                isFinal: true,
                timestamp: Date(),
                language: nil,
                duration: nil
            )
            
            transcriptionText = text
            isTranscribing = false
            
            return transcriptionResult
            
        } catch {
            isTranscribing = false
            self.error = .transcriptionFailed(error.localizedDescription)
            throw error
        }
    }
    
    /// Transcribe audio from PCM buffer (for real-time streaming)
    func transcribe(audioBuffer: AVAudioPCMBuffer) async throws -> TranscriptionResult {
        guard isInitialized else {
            throw WhisperError.notInitialized
        }
        
        // TODO: Implement streaming transcription with WhisperKit
        // This will be used for real-time transcription
        
        throw WhisperError.notImplemented
    }
    
    /// Start real-time transcription from microphone
    func startRealtimeTranscription() async throws {
        guard isInitialized else {
            throw WhisperError.notInitialized
        }
        
        // TODO: Implement real-time audio capture and transcription
        // This will involve:
        // 1. Setting up AVAudioEngine
        // 2. Capturing audio buffers
        // 3. Feeding them to WhisperKit incrementally
        // 4. Publishing interim and final results
        
        isTranscribing = true
    }
    
    /// Stop real-time transcription
    func stopRealtimeTranscription() {
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        isTranscribing = false
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        stopRealtimeTranscription()
        whisperKit = nil
        isInitialized = false
    }
}

// MARK: - Whisper Error Types

enum WhisperError: LocalizedError {
    case notInitialized
    case initializationFailed(String)
    case alreadyTranscribing
    case transcriptionFailed(String)
    case modelNotFound(String)
    case notImplemented
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return NSLocalizedString("error.whisper.not_initialized", comment: "WhisperKit is not initialized")
        case .initializationFailed(let message):
            return NSLocalizedString("error.whisper.init_failed", comment: "Failed to initialize: \(message)")
        case .alreadyTranscribing:
            return NSLocalizedString("error.whisper.already_transcribing", comment: "Already transcribing")
        case .transcriptionFailed(let message):
            return NSLocalizedString("error.whisper.transcription_failed", comment: "Transcription failed: \(message)")
        case .modelNotFound(let model):
            return NSLocalizedString("error.whisper.model_not_found", comment: "Model not found: \(model)")
        case .notImplemented:
            return NSLocalizedString("error.whisper.not_implemented", comment: "Feature not implemented yet")
        }
    }
}
