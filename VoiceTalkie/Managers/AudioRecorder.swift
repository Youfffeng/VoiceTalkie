//
//  AudioRecorder.swift
//  VoiceTalkie
//
//  Created by Qoder on 11/18/25.
//

import Foundation
import AVFoundation
import Combine

/// Manager for audio recording using AVAudioEngine
@MainActor
class AudioRecorder: ObservableObject {
    static let shared = AudioRecorder()
    
    // MARK: - Published Properties
    
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    @Published var recordingDuration: TimeInterval = 0.0
    @Published var error: AudioRecorderError?
    
    // MARK: - Private Properties
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioFile: AVAudioFile?
    private var recordingStartTime: Date?
    private var levelTimer: Timer?
    
    // Audio format settings
    private let sampleRate: Double = 16000.0  // WhisperKit preferred sample rate
    private let channelCount: AVAudioChannelCount = 1  // Mono
    
    private init() {}
    
    // MARK: - Recording Control
    
    /// Start recording audio
    func startRecording() throws {
        guard !isRecording else {
            throw AudioRecorderError.alreadyRecording
        }
        
        // Create audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw AudioRecorderError.engineCreationFailed
        }
        
        inputNode = audioEngine.inputNode
        guard let inputNode = inputNode else {
            throw AudioRecorderError.noInputNode
        }
        
        // Configure audio format
        let inputFormat = inputNode.outputFormat(forBus: 0)
        let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channelCount,
            interleaved: false
        )
        
        guard let recordingFormat = recordingFormat else {
            throw AudioRecorderError.formatCreationFailed
        }
        
        // Create temporary file for recording
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "recording_\(UUID().uuidString).wav"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            audioFile = try AVAudioFile(
                forWriting: fileURL,
                settings: recordingFormat.settings,
                commonFormat: recordingFormat.commonFormat,
                interleaved: recordingFormat.isInterleaved
            )
        } catch {
            throw AudioRecorderError.fileCreationFailed(error.localizedDescription)
        }
        
        // Install tap on input node
        inputNode.installTap(
            onBus: 0,
            bufferSize: 4096,
            format: inputFormat
        ) { [weak self] buffer, time in
            guard let self = self, let audioFile = self.audioFile else { return }
            
            // Convert to recording format if needed
            if let converter = self.createConverter(from: inputFormat, to: recordingFormat) {
                if let convertedBuffer = self.convert(buffer: buffer, using: converter, to: recordingFormat) {
                    do {
                        try audioFile.write(from: convertedBuffer)
                    } catch {
                        Task { @MainActor in
                            self.error = .writeFailed(error.localizedDescription)
                        }
                    }
                }
            }
            
            // Update audio level
            Task { @MainActor in
                self.updateAudioLevel(from: buffer)
            }
        }
        
        // Start engine
        do {
            try audioEngine.start()
            isRecording = true
            recordingStartTime = Date()
            
            // Start duration timer
            startDurationTimer()
            
            print("✅ Recording started")
        } catch {
            throw AudioRecorderError.engineStartFailed(error.localizedDescription)
        }
    }
    
    /// Stop recording and return the audio file URL
    func stopRecording() -> URL? {
        guard isRecording else { return nil }
        
        // Stop engine
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        
        // Stop timers
        levelTimer?.invalidate()
        levelTimer = nil
        
        // Get file URL
        let fileURL = audioFile?.url
        
        // Cleanup
        audioFile = nil
        audioEngine = nil
        inputNode = nil
        isRecording = false
        audioLevel = 0.0
        recordingDuration = 0.0
        recordingStartTime = nil
        
        print("✅ Recording stopped, file: \(fileURL?.lastPathComponent ?? "none")")
        
        return fileURL
    }
    
    /// Cancel recording without saving
    func cancelRecording() {
        guard isRecording else { return }
        
        let fileURL = audioFile?.url
        
        // Stop recording
        _ = stopRecording()
        
        // Delete temp file
        if let fileURL = fileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createConverter(from: AVAudioFormat, to: AVAudioFormat) -> AVAudioConverter? {
        return AVAudioConverter(from: from, to: to)
    }
    
    private func convert(buffer: AVAudioPCMBuffer, using converter: AVAudioConverter, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * format.sampleRate / buffer.format.sampleRate)
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            return nil
        }
        
        var error: NSError?
        let status = converter.convert(to: convertedBuffer, error: &error) { packetCount, statusPtr in
            statusPtr.pointee = .haveData
            return buffer
        }
        
        if status == .error {
            return nil
        }
        
        return convertedBuffer
    }
    
    private func updateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(
            from: 0,
            to: Int(buffer.frameLength),
            by: buffer.stride
        ).map { channelDataValue[$0] }
        
        let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
        let avgPower = 20 * log10(rms)
        let normalizedLevel = max(0, min(1, (avgPower + 50) / 50))
        
        audioLevel = normalizedLevel
    }
    
    private func startDurationTimer() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.recordingStartTime else { return }
            Task { @MainActor in
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }
        }
    }
}

// MARK: - Audio Recorder Error

enum AudioRecorderError: LocalizedError {
    case alreadyRecording
    case engineCreationFailed
    case noInputNode
    case formatCreationFailed
    case fileCreationFailed(String)
    case engineStartFailed(String)
    case writeFailed(String)
    case notRecording
    
    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return NSLocalizedString("error.audio.already_recording", comment: "Already recording")
        case .engineCreationFailed:
            return NSLocalizedString("error.audio.engine_failed", comment: "Failed to create audio engine")
        case .noInputNode:
            return NSLocalizedString("error.audio.no_input", comment: "No audio input available")
        case .formatCreationFailed:
            return NSLocalizedString("error.audio.format_failed", comment: "Failed to create audio format")
        case .fileCreationFailed(let message):
            return NSLocalizedString("error.audio.file_failed", comment: "Failed to create audio file: \(message)")
        case .engineStartFailed(let message):
            return NSLocalizedString("error.audio.start_failed", comment: "Failed to start recording: \(message)")
        case .writeFailed(let message):
            return NSLocalizedString("error.audio.write_failed", comment: "Failed to write audio: \(message)")
        case .notRecording:
            return NSLocalizedString("error.audio.not_recording", comment: "Not currently recording")
        }
    }
}
