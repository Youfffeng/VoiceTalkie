//
//  TranscriptionResult.swift
//  VoiceTalkie
//
//  Created by Qoder on 11/18/25.
//

import Foundation

/// Represents the result of a speech recognition transcription
struct TranscriptionResult {
    /// The transcribed text
    let text: String
    
    /// Confidence score (0.0 to 1.0)
    let confidence: Double?
    
    /// Whether this is a final result or interim
    let isFinal: Bool
    
    /// Timestamp when transcription was completed
    let timestamp: Date
    
    /// Language code (e.g., "zh-CN", "en-US")
    let language: String?
    
    /// Duration of the audio that was transcribed (in seconds)
    let duration: TimeInterval?
    
    init(
        text: String,
        confidence: Double? = nil,
        isFinal: Bool = true,
        timestamp: Date = Date(),
        language: String? = nil,
        duration: TimeInterval? = nil
    ) {
        self.text = text
        self.confidence = confidence
        self.isFinal = isFinal
        self.timestamp = timestamp
        self.language = language
        self.duration = duration
    }
}

/// Whisper model variants
enum WhisperModel: String, CaseIterable, Identifiable {
    case tiny = "tiny"
    case base = "base"
    case small = "small"
    case medium = "medium"
    case largeV3 = "large-v3"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .tiny: return "Tiny (~40MB)"
        case .base: return "Base (~75MB)"
        case .small: return "Small (~245MB)"
        case .medium: return "Medium (~770MB)"
        case .largeV3: return "Large V3 (~1.5GB)"
        }
    }
    
    var estimatedSize: String {
        switch self {
        case .tiny: return "40 MB"
        case .base: return "75 MB"
        case .small: return "245 MB"
        case .medium: return "770 MB"
        case .largeV3: return "1.5 GB"
        }
    }
    
    var description: String {
        switch self {
        case .tiny: return NSLocalizedString("model.tiny.description", comment: "Fast, basic accuracy")
        case .base: return NSLocalizedString("model.base.description", comment: "Good balance")
        case .small: return NSLocalizedString("model.small.description", comment: "Recommended - High accuracy")
        case .medium: return NSLocalizedString("model.medium.description", comment: "Very high accuracy")
        case .largeV3: return NSLocalizedString("model.large.description", comment: "Best accuracy, slower")
        }
    }
}
