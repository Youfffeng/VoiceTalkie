//
//  RecordingIndicatorView.swift
//  VoiceTalkie
//
//  Created by Qoder on 11/18/25.
//

import SwiftUI

struct RecordingIndicatorView: View {
    @ObservedObject var coordinator = VoiceTalkieCoordinator.shared
    @ObservedObject var audioRecorder = AudioRecorder.shared
    
    var body: some View {
        VStack(spacing: 12) {
            // Status Icon
            if coordinator.isRecording {
                recordingIndicator
            } else if coordinator.isTranscribing {
                transcribingIndicator
            }
            
            // Audio Level Meter
            if coordinator.isRecording {
                audioLevelMeter
            }
            
            // Current Text
            if !coordinator.currentText.isEmpty {
                textPreview
            }
            
            // Error Message
            if let error = coordinator.error {
                errorView(error)
            }
        }
        .padding()
        .background(Material.regular)
        .cornerRadius(12)
        .shadow(radius: 10)
    }
    
    // MARK: - Recording Indicator
    
    private var recordingIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.red.opacity(0.3), lineWidth: 4)
                        .scaleEffect(1.5)
                        .opacity(0.8)
                        .animation(
                            .easeInOut(duration: 1)
                            .repeatForever(autoreverses: true),
                            value: coordinator.isRecording
                        )
                )
            
            Text("recording")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(timeString(audioRecorder.recordingDuration))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Transcribing Indicator
    
    private var transcribingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            
            Text("transcribing")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Audio Level Meter
    
    private var audioLevelMeter: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                
                // Level Bar
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [.green, .yellow, .orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * CGFloat(audioRecorder.audioLevel))
                    .animation(.linear(duration: 0.1), value: audioRecorder.audioLevel)
            }
        }
        .frame(height: 8)
    }
    
    // MARK: - Text Preview
    
    private var textPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("transcribed_text")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(coordinator.currentText)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: 300, alignment: .leading)
    }
    
    // MARK: - Error View
    
    private func errorView(_ error: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Helpers
    
    private func timeString(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    RecordingIndicatorView()
        .frame(width: 320)
}
