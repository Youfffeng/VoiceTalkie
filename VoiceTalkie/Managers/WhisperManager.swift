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
    @Published var isDownloading = false
    @Published var transcriptionText = ""
    @Published var error: WhisperError?
    
    // MARK: - Private Properties
    
    private var whisperKit: WhisperKit?
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    
    /// 本地模型存储路径（Application Support）
    private lazy var localModelsPath: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelsDir = appSupport.appendingPathComponent("whisperkit-models")
        
        // 确保目录存在
        try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        
        return modelsDir
    }()
    
    /// Bundle中预打包的模型路径
    private var bundledModelPath: URL? {
        // 查找 Bundle 中的模型文件夹
        // 模型文件夹命名格式：openai_whisper-{model_name}
        return Bundle.main.url(forResource: "openai_whisper-\(currentModel.rawValue)", withExtension: nil)
    }
    
    // MARK: - Initialization
    
    private init() {
        // Load saved model preference
        if let savedModel = UserDefaults.standard.string(forKey: "selectedWhisperModel"),
           let model = WhisperModel(rawValue: savedModel) {
            currentModel = model
        }
    }
    
    // MARK: - Model Management
    
    /// 检测并准备本地模型
    private func prepareLocalModel(modelName: String) -> URL? {
        // 添加自动释放池，防止内存问题
        return autoreleasepool {
            let modelFolderName = "openai_whisper-\(modelName)"
            let localModelPath = localModelsPath.appendingPathComponent(modelFolderName)
            
            print("\n🔍 [WhisperManager] ========== 开始检测模型 ==========")
            print("📝 [WhisperManager] 目标模型: \(modelName)")
        
        // 1. 检查 Application Support 中是否已有模型
        if FileManager.default.fileExists(atPath: localModelPath.path) {
            print("✅ [WhisperManager] 找到本地模型: \(localModelPath.path)")
            print("🔍 [WhisperManager] ========== 模型检测完成 ==========\n")
            return localModelPath
        }
        
        // 2. 检查 Bundle 中是否有预打包模型（带文件夹结构）
        print("🔎 [WhisperManager] Application Support中不存在，检查Bundle...")
        
        if let bundledPath = Bundle.main.url(forResource: modelFolderName, withExtension: nil) {
            print("📦 [WhisperManager] ✅ 找到Bundle中的模型（文件夹结构）: \(bundledPath.path)")
            
            // 尝试复制到 Application Support
            print("📋 [WhisperManager] 尝试复制模型到Application Support...")
            do {
                try FileManager.default.copyItem(at: bundledPath, to: localModelPath)
                print("✅ [WhisperManager] 已复制模型到本地: \(localModelPath.path)")
                print("🔍 [WhisperManager] ========== 模型检测完成 ==========\n")
                return localModelPath
            } catch {
                print("⚠️ [WhisperManager] 复制模型失败: \(error.localizedDescription)")
                print("   将直接使用Bundle路径")
                print("🔍 [WhisperManager] ========== 模型检测完成 ==========\n")
                // 如果复制失败，直接使用 Bundle 路径
                return bundledPath
            }
        }
        
        // 3. 检查 Bundle Resources 根目录（文件被展开的情况）
        print("🔎 [WhisperManager] 未找到文件夹结构，检查Bundle根目录中的模型文件...")
        
        if let resourceURL = Bundle.main.resourceURL {
            // 检查关键的模型文件是否存在于Bundle根目录
            let audioEncoderPath = resourceURL.appendingPathComponent("AudioEncoder.mlmodelc")
            let textDecoderPath = resourceURL.appendingPathComponent("TextDecoder.mlmodelc")
            let melSpectrogramPath = resourceURL.appendingPathComponent("MelSpectrogram.mlmodelc")
            let configPath = resourceURL.appendingPathComponent("config.json")
            
            let hasAllFiles = FileManager.default.fileExists(atPath: audioEncoderPath.path) &&
                             FileManager.default.fileExists(atPath: textDecoderPath.path) &&
                             FileManager.default.fileExists(atPath: melSpectrogramPath.path) &&
                             FileManager.default.fileExists(atPath: configPath.path)
            
            if hasAllFiles {
                print("📦 [WhisperManager] ✅ 找到Bundle根目录中的模型文件")
                print("📋 [WhisperManager] 模型文件位置: \(resourceURL.path)")
                
                // 创建目标文件夹
                do {
                    try FileManager.default.createDirectory(at: localModelPath, withIntermediateDirectories: true)
                    
                    // 复制所有模型相关文件到目标文件夹
                    let filesToCopy = [
                        "AudioEncoder.mlmodelc",
                        "AudioEncoder.mlcomputeplan.json",
                        "TextDecoder.mlmodelc",
                        "TextDecoder.mlcomputeplan.json",
                        "MelSpectrogram.mlmodelc",
                        "MelSpectrogram.mlcomputeplan.json",
                        "config.json",
                        "generation_config.json",
                        "tokenizer.json",
                        "tokenizer_config.json",
                        "vocab.json",
                        "merges.txt"
                    ]
                    
                    for fileName in filesToCopy {
                        let sourcePath = resourceURL.appendingPathComponent(fileName)
                        let destPath = localModelPath.appendingPathComponent(fileName)
                        
                        if FileManager.default.fileExists(atPath: sourcePath.path) {
                            // 如果目标已存在，先删除
                            if FileManager.default.fileExists(atPath: destPath.path) {
                                try? FileManager.default.removeItem(at: destPath)
                            }
                            try FileManager.default.copyItem(at: sourcePath, to: destPath)
                        }
                    }
                    
                    print("✅ [WhisperManager] 已重组模型文件到本地: \(localModelPath.path)")
                    print("🔍 [WhisperManager] ========== 模型检测完成 ==========\n")
                    return localModelPath
                    
                } catch {
                    print("⚠️ [WhisperManager] 重组模型文件失败: \(error.localizedDescription)")
                    print("   将直接使用Bundle根目录")
                    print("🔍 [WhisperManager] ========== 模型检测完成 ==========\n")
                    // 直接返回Bundle的resourceURL，让WhisperKit从那里加载
                    return resourceURL
                }
            }
        }
        
        print("❌ [WhisperManager] 未找到本地或Bundle中的模型: \(modelFolderName)")
        print("🔍 [WhisperManager] ========== 模型检测完成(未找到) ==========\n")
        return nil
        } // autoreleasepool
    }
    
    /// Initialize WhisperKit with specified model
    func initialize(model: WhisperModel? = nil) async throws {
        let modelToUse = model ?? currentModel
        
        print("\n🚀 [WhisperManager] ========== 开始初始化WhisperKit ==========")
        print("📝 [WhisperManager] 请求的模型: \(modelToUse.rawValue)")
        print("📝 [WhisperManager] 当前模型: \(currentModel.rawValue)")
        print("📝 [WhisperManager] 初始化状态: \(isInitialized)")
        
        guard !isInitialized else {
            print("⚠️ [WhisperManager] WhisperKit已经初始化，跳过")
            print("🚀 [WhisperManager] ========== 初始化结束 ==========\n")
            return
        }
        
        isDownloading = true
        downloadProgress = 0.0
        
        do {
            // 先尝试使用本地模型
            if let localModelPath = prepareLocalModel(modelName: modelToUse.rawValue) {
                print("\n📁 [WhisperManager] 准备使用本地模型")
                print("📂 [WhisperManager] 模型文件夹路径: \(localModelPath.path)")
                
                let config = WhisperKitConfig(
                    modelFolder: localModelPath.path,
                    verbose: true,
                    logLevel: .debug
                )
                
                print("⚙️ [WhisperManager] WhisperKitConfig:")
                print("   - modelFolder: \(config.modelFolder ?? "nil")")
                
                // 验证模型文件完整性
                print("\n🔍 [WhisperManager] 验证模型文件...")
                let requiredFiles = [
                    "AudioEncoder.mlmodelc/model.mil",
                    "AudioEncoder.mlmodelc/coremldata.bin",
                    "MelSpectrogram.mlmodelc/model.mil",
                    "MelSpectrogram.mlmodelc/coremldata.bin",
                    "TextDecoder.mlmodelc/model.mil",
                    "TextDecoder.mlmodelc/coremldata.bin",
                    "config.json",
                    "tokenizer.json"
                ]
                
                for file in requiredFiles {
                    let filePath = localModelPath.appendingPathComponent(file)
                    let exists = FileManager.default.fileExists(atPath: filePath.path)
                    let size = (try? FileManager.default.attributesOfItem(atPath: filePath.path)[.size] as? UInt64) ?? 0
                    print("   \(exists ? "✅" : "❌") \(file): \(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))")
                }
                
                print("\n🔄 [WhisperManager] 开始创建WhisperKit实例...")
                print("⏰ [WhisperManager] 这可能需要 10-30 秒，请耐心等待...")
                
                let startTime = Date()
                whisperKit = try await WhisperKit(config)
                let duration = Date().timeIntervalSince(startTime)
                
                print("⏱️ [WhisperManager] WhisperKit 初始化耗时: \(String(format: "%.2f", duration)) 秒")
                
                isInitialized = true
                currentModel = modelToUse
                isDownloading = false
                
                UserDefaults.standard.set(modelToUse.rawValue, forKey: "selectedWhisperModel")
                print("✅ [WhisperManager] 使用本地模型初始化成功: \(modelToUse.rawValue)")
                print("🚀 [WhisperManager] ========== 初始化成功 ==========\n")
                return
            }
            
            // 如果没有本地模型，则从网络下载
            print("\n🌐 [WhisperManager] 本地模型不存在，准备从网络下载")
            print("📂 [WhisperManager] 下载目标路径: \(localModelsPath.path)")
            
            let config = WhisperKitConfig(
                model: modelToUse.rawValue,
                modelFolder: localModelsPath.path,
                verbose: false,
                logLevel: .none
            )
            
            print("⚙️ [WhisperManager] WhisperKitConfig:")
            print("   - model: \(config.model ?? "nil")")
            print("   - modelFolder: \(config.modelFolder ?? "nil")")
            
            print("🔄 [WhisperManager] 开始创建WhisperKit实例(将从网络下载)...")
            whisperKit = try await WhisperKit(config)
            
            isInitialized = true
            currentModel = modelToUse
            isDownloading = false
            
            UserDefaults.standard.set(modelToUse.rawValue, forKey: "selectedWhisperModel")
            print("✅ [WhisperManager] 网络下载模型初始化成功: \(modelToUse.rawValue)")
            print("🚀 [WhisperManager] ========== 初始化成功 ==========\n")
            
        } catch {
            isDownloading = false
            self.error = .initializationFailed(error.localizedDescription)
            print("\n❌ [WhisperManager] 模型初始化失败")
            print("   错误类型: \(type(of: error))")
            print("   错误描述: \(error.localizedDescription)")
            print("   详细信息: \(error)")
            print("🚀 [WhisperManager] ========== 初始化失败 ==========\n")
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
    
    /// 检查模型是否本地可用
    func isModelAvailableLocally(_ model: WhisperModel) -> Bool {
        let modelFolderName = "openai_whisper-\(model.rawValue)"
        
        // 检查 Application Support
        let localPath = localModelsPath.appendingPathComponent(modelFolderName)
        if FileManager.default.fileExists(atPath: localPath.path) {
            return true
        }
        
        // 检查 Bundle
        if Bundle.main.url(forResource: modelFolderName, withExtension: nil) != nil {
            return true
        }
        
        return false
    }
    
    /// 获取模型文件大小（如果存在）
    func getModelSize(_ model: WhisperModel) -> String? {
        let modelFolderName = "openai_whisper-\(model.rawValue)"
        
        // 检查 Application Support
        let localPath = localModelsPath.appendingPathComponent(modelFolderName)
        if FileManager.default.fileExists(atPath: localPath.path),
           let size = try? FileManager.default.attributesOfItem(atPath: localPath.path)[.size] as? UInt64 {
            return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        }
        
        // 检查 Bundle
        if let bundlePath = Bundle.main.url(forResource: modelFolderName, withExtension: nil),
           let size = try? FileManager.default.attributesOfItem(atPath: bundlePath.path)[.size] as? UInt64 {
            return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        }
        
        return nil
    }
    
    // MARK: - Transcription
    
    /// Transcribe audio from a file URL
    func transcribe(audioURL: URL) async throws -> TranscriptionResult {
        print("🤖 [WhisperManager] transcribe() called")
        print("📁 [WhisperManager] Audio file: \(audioURL.path)")
        
        guard isInitialized else {
            print("❌ [WhisperManager] WhisperKit not initialized")
            throw WhisperError.notInitialized
        }
        print("✅ [WhisperManager] WhisperKit is initialized")
        
        guard !isTranscribing else {
            print("⚠️ [WhisperManager] Already transcribing")
            throw WhisperError.alreadyTranscribing
        }
        
        isTranscribing = true
        transcriptionText = ""
        print("🔄 [WhisperManager] Starting transcription with model: \(currentModel.rawValue)")
        
        do {
            let startTime = Date()
            
            // 获取用户自定义的 prompt
            let settings = AppSettings.shared
            let promptText = settings.whisperPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            
            var promptTokens: [Int]? = nil
            if !promptText.isEmpty, let tokenizer = whisperKit?.tokenizer {
                // 将 prompt 文本转换为 tokens
                promptTokens = tokenizer.encode(text: promptText).filter { $0 < tokenizer.specialTokens.specialTokenBegin }
                print("📝 [WhisperManager] Using prompt: '\(promptText)'")
                print("🔢 [WhisperManager] Prompt tokens count: \(promptTokens?.count ?? 0)")
            }
            
            // 🌏 强制使用中文识别
            print("🌏 [WhisperManager] Using language: Chinese (zh)")
            let result = try await whisperKit?.transcribe(
                audioPath: audioURL.path,
                decodeOptions: DecodingOptions(
                    task: .transcribe,
                    language: "zh",  // 强制中文
                    temperature: 0.0,
                    temperatureFallbackCount: 5,
                    sampleLength: 224,
                    topK: 5,
                    usePrefillPrompt: true,
                    usePrefillCache: true,
                    promptTokens: promptTokens  // 使用自定义 prompt
                )
            ) ?? []
            
            let duration = Date().timeIntervalSince(startTime)
            
            print("⏱️ [WhisperManager] Transcription took \(String(format: "%.2f", duration)) seconds")
            print("📊 [WhisperManager] Result count: \(result.count)")
            
            let text = result.first?.text ?? ""
            print("📝 [WhisperManager] Raw transcription result: '\(text)'")
            print("📏 [WhisperManager] Text length: \(text.count) characters")
            
            let transcriptionResult = TranscriptionResult(
                text: text,
                confidence: nil,
                isFinal: true,
                timestamp: Date(),
                language: nil,
                duration: duration
            )
            
            transcriptionText = text
            isTranscribing = false
            
            print("✅ [WhisperManager] Transcription completed successfully")
            return transcriptionResult
            
        } catch {
            print("❌ [WhisperManager] Transcription error: \(error)")
            print("❌ [WhisperManager] Error description: \(error.localizedDescription)")
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
