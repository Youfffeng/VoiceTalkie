//
//  AudioRecorder.swift
//  VoiceTalkie
//
//  Created by Qoder on 11/18/25.
//

import Foundation
@preconcurrency import AVFoundation
import Combine
import CoreAudio
import AppKit

/// 音频输入设备信息
struct AudioInputDevice: Identifiable, Equatable {
    let id: String  // 设备唯一 ID
    let name: String  // 设备显示名称
    let isDefault: Bool  // 是否为系统默认设备
}

/// Manager for audio recording using AVAudioEngine
@MainActor
class AudioRecorder: ObservableObject {
    static let shared = AudioRecorder()
    
    // MARK: - Published Properties
    
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    @Published var recordingDuration: TimeInterval = 0.0
    @Published var error: AudioRecorderError?
    @Published var availableInputDevices: [AudioInputDevice] = [] // 可用输入设备列表
    
    // MARK: - Private Properties
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioFile: AVAudioFile?
    private var recordingStartTime: Date?
    private var levelTimer: Timer?
    
    // Audio format settings
    private let sampleRate: Double = 16000.0  // WhisperKit preferred sample rate
    private let channelCount: AVAudioChannelCount = 1  // Mono
    
    private init() {
        // 加载可用设备
        refreshAvailableDevices()
    }
    
    // MARK: - Device Management
    
    /// 刷新可用音频输入设备列表
    func refreshAvailableDevices() {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone, .externalUnknown],
            mediaType: .audio,
            position: .unspecified
        )
        
        availableInputDevices = discoverySession.devices.map { device in
            AudioInputDevice(
                id: device.uniqueID,
                name: device.localizedName,
                isDefault: device.uniqueID == AVCaptureDevice.default(for: .audio)?.uniqueID
            )
        }
        
        print("📊 [AudioRecorder] Refreshed devices: \(availableInputDevices.count) found")
    }
    
    // MARK: - Recording Control
    
    /// Start recording audio
    func startRecording() async throws {
        print("🎙️ [AudioRecorder] startRecording() called")
        
        // 列出所有可用的音频输入设备
        listAvailableAudioInputDevices()
        
        // 获取用户选择的设备
        let selectedDeviceID = AppSettings.shared.selectedAudioInputDeviceID
        if !selectedDeviceID.isEmpty {
            print("🎤 [AudioRecorder] User selected device ID: \(selectedDeviceID)")
            // 查找对应设备
            if let selectedDevice = availableInputDevices.first(where: { $0.id == selectedDeviceID }) {
                print("✅ [AudioRecorder] Will use: \(selectedDevice.name)")
            } else {
                print("⚠️ [AudioRecorder] Selected device not found, falling back to system default")
            }
        } else {
            print("🎵 [AudioRecorder] Using system default audio input device")
        }
        
        // Check microphone permission first
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        print("🎤 [AudioRecorder] Microphone permission status: \(status.rawValue)")
        guard status == .authorized else {
            print("❌ [AudioRecorder] Microphone not authorized - will not start engine")
            throw AudioRecorderError.engineCreationFailed
        }
        
        guard !isRecording else {
            print("⚠️ [AudioRecorder] Already recording")
            throw AudioRecorderError.alreadyRecording
        }
        print("🎵 [AudioRecorder] Creating audio engine...")
        
        // Create audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            print("❌ [AudioRecorder] Failed to create audio engine")
            throw AudioRecorderError.engineCreationFailed
        }
        print("✅ [AudioRecorder] Audio engine created")
        
        // 检查当前音频输入设备
        let currentInputDevice = audioEngine.inputNode.auAudioUnit.deviceID
        print("🎤 [AudioRecorder] Current input device ID: \(currentInputDevice)")
        
        inputNode = audioEngine.inputNode
        guard let inputNode = inputNode else {
            print("❌ [AudioRecorder] No input node available")
            throw AudioRecorderError.noInputNode
        }
        print("✅ [AudioRecorder] Input node acquired")
        
        // 检查输入节点的连接状态
        let isInputAvailable = inputNode.inputFormat(forBus: 0).channelCount > 0
        print("📊 [AudioRecorder] Input available: \(isInputAvailable)")
        if !isInputAvailable {
            print("⚠️ [AudioRecorder] WARNING: Input node has no channels! No microphone connected?")
        }
        
        // Configure audio format
        let inputFormat = inputNode.outputFormat(forBus: 0)
        print("📊 [AudioRecorder] Input format from device:")
        print("   - Sample Rate: \(inputFormat.sampleRate) Hz")
        print("   - Channels: \(inputFormat.channelCount)")
        print("   - Format: \(inputFormat.commonFormat.rawValue)")
        print("   - Interleaved: \(inputFormat.isInterleaved)")
        
        // 检查输入格式是否有效
        if inputFormat.channelCount == 0 {
            print("❌ [AudioRecorder] CRITICAL: Input format has 0 channels!")
            print("❌ [AudioRecorder] This means no audio input device is available or selected")
            throw AudioRecorderError.noInputNode
        }
        
        let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channelCount,
            interleaved: false
        )
        
        guard let recordingFormat = recordingFormat else {
            print("❌ [AudioRecorder] Failed to create recording format")
            throw AudioRecorderError.formatCreationFailed
        }
        print("✅ [AudioRecorder] Recording format created: \(sampleRate)Hz, \(channelCount) channel(s)")
        
        // Create temporary file for recording
        let tempDir = FileManager.default.temporaryDirectory
        print("📁 [AudioRecorder] Temporary directory: \(tempDir.path)")
        
        // 确保临时目录存在
        if !FileManager.default.fileExists(atPath: tempDir.path) {
            print("⚠️ [AudioRecorder] Temporary directory does not exist, creating...")
            do {
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                print("✅ [AudioRecorder] Temporary directory created")
            } catch {
                print("❌ [AudioRecorder] Failed to create temporary directory: \(error)")
                throw AudioRecorderError.fileCreationFailed("Cannot create temp directory: \(error.localizedDescription)")
            }
        }
        
        let fileName = "recording_\(UUID().uuidString).wav"
        let fileURL = tempDir.appendingPathComponent(fileName)
        print("📄 [AudioRecorder] Will create audio file at: \(fileURL.path)")
        
        do {
            audioFile = try AVAudioFile(
                forWriting: fileURL,
                settings: recordingFormat.settings,
                commonFormat: recordingFormat.commonFormat,
                interleaved: recordingFormat.isInterleaved
            )
            print("✅ [AudioRecorder] Audio file created at: \(fileURL.path)")
        } catch {
            print("❌ [AudioRecorder] Failed to create audio file: \(error)")
            throw AudioRecorderError.fileCreationFailed(error.localizedDescription)
        }
        
        // Install tap on input node
        print("🎧 [AudioRecorder] Installing audio tap on input node...")
        print("📊 [AudioRecorder] Input format: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount) channel(s)")
        print("📊 [AudioRecorder] Recording format: \(recordingFormat.sampleRate)Hz, \(recordingFormat.channelCount) channel(s)")
        
        var bufferCount = 0
        var totalFrames: AVAudioFrameCount = 0
        
        inputNode.installTap(
            onBus: 0,
            bufferSize: 4096,
            format: inputFormat
        ) { [weak self] buffer, time in
            guard let self = self, let audioFile = self.audioFile else { return }
            
            bufferCount += 1
            totalFrames += buffer.frameLength
            
            // Log first few buffers
            if bufferCount <= 3 || bufferCount % 50 == 0 {
                print("🎵 [AudioRecorder] Buffer #\(bufferCount): \(buffer.frameLength) frames, total: \(totalFrames) frames")
            }
            
            // Convert to recording format if needed
            if let converter = self.createConverter(from: inputFormat, to: recordingFormat) {
                if let convertedBuffer = self.convert(buffer: buffer, using: converter, to: recordingFormat) {
                    do {
                        try audioFile.write(from: convertedBuffer)
                        if bufferCount <= 3 {
                            print("✅ [AudioRecorder] Buffer #\(bufferCount) written to file successfully")
                        }
                    } catch {
                        print("❌ [AudioRecorder] Failed to write buffer #\(bufferCount): \(error)")
                        Task { @MainActor in
                            self.error = .writeFailed(error.localizedDescription)
                        }
                    }
                } else {
                    print("⚠️ [AudioRecorder] Failed to convert buffer #\(bufferCount)")
                }
            } else {
                print("⚠️ [AudioRecorder] Failed to create converter")
            }
            
            // Update audio level
            Task { @MainActor in
                self.updateAudioLevel(from: buffer)
            }
        }
        print("✅ [AudioRecorder] Audio tap installed successfully")
        
        // Start engine
        do {
            print("🚀 [AudioRecorder] Starting audio engine...")
            try audioEngine.start()
            isRecording = true
            recordingStartTime = Date()
            
            // Start duration timer
            startDurationTimer()
            
            print("✅ [AudioRecorder] Recording started successfully!")
            print("📊 [AudioRecorder] isRecording = \(isRecording)")
        } catch {
            print("❌ [AudioRecorder] Failed to start engine: \(error)")
            throw AudioRecorderError.engineStartFailed(error.localizedDescription)
        }
    }
    
    /// Stop recording and return the audio file URL
    func stopRecording() -> URL? {
        print("🛑 [AudioRecorder] stopRecording() called")
        guard isRecording else {
            print("⚠️ [AudioRecorder] Not recording, cannot stop")
            return nil
        }
        
        print("⏸️ [AudioRecorder] Stopping audio engine...")
        // Stop engine
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        
        // Stop timers
        levelTimer?.invalidate()
        levelTimer = nil
        
        // Get file URL
        let fileURL = audioFile?.url
        
        print("📊 [AudioRecorder] Recording duration: \(recordingDuration) seconds")
        print("📁 [AudioRecorder] Audio file: \(fileURL?.lastPathComponent ?? "none")")
        
        // Cleanup
        audioFile = nil
        audioEngine = nil
        inputNode = nil
        isRecording = false
        audioLevel = 0.0
        recordingDuration = 0.0
        recordingStartTime = nil
        
        print("✅ [AudioRecorder] Recording stopped successfully")
        
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
    
    /// 列出所有可用的音频输入设备 - 简化版本
    private func listAvailableAudioInputDevices() {
        print("💻 [AudioRecorder] ========== Checking Audio Input Devices ==========")
        
        // 使用 AVCaptureDevice 的简单方法
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone, .externalUnknown],
            mediaType: .audio,
            position: .unspecified
        )
        
        let audioDevices = discoverySession.devices
        print("📊 [AudioRecorder] Found \(audioDevices.count) audio input devices")
        
        for (index, device) in audioDevices.enumerated() {
            print("🎤 [AudioRecorder] Device #\(index): \(device.localizedName)")
            print("   - Unique ID: \(device.uniqueID)")
            print("   - Has Audio: \(device.hasMediaType(.audio))")
        }
        
        // 检查默认设备
        if let defaultDevice = AVCaptureDevice.default(for: .audio) {
            print("✅ [AudioRecorder] Default audio device: \(defaultDevice.localizedName)")
        } else {
            print("❌ [AudioRecorder] No default audio device found!")
        }
        
        print("💻 [AudioRecorder] =====================================================")
    }
    
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
            print("⚠️ [AudioRecorder] Converter error: \(error?.localizedDescription ?? "unknown")")
            return nil
        }
        
        return convertedBuffer
    }
    
    private func updateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else {
            print("⚠️ [AudioRecorder] No channel data in buffer")
            return
        }
        
        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(
            from: 0,
            to: Int(buffer.frameLength),
            by: buffer.stride
        ).map { channelDataValue[$0] }
        
        let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
        let avgPower = 20 * log10(rms)
        let normalizedLevel = max(0, min(1, (avgPower + 50) / 50))
        
        let previousLevel = audioLevel
        audioLevel = normalizedLevel
        
        // Log significant level changes
        if abs(normalizedLevel - previousLevel) > 0.1 {
            print("🔊 [AudioRecorder] Audio level: \(String(format: "%.2f", normalizedLevel)) (RMS: \(String(format: "%.4f", rms)), Power: \(String(format: "%.2f", avgPower)) dB)")
        }
    }
    
    private func startDurationTimer() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                guard let startTime = self.recordingStartTime else { return }
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
