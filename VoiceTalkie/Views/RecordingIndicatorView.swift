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
    @State private var isActive = true
    
    var body: some View {
        VStack(spacing: 8) {
            // Recording Status with Audio Level
            if coordinator.isRecording {
                compactRecordingView
            } else if coordinator.isTranscribing {
                compactTranscribingView
            }
            
            // Error Message (compact)
            if let error = coordinator.error {
                compactErrorView(error)
            }
        }
        .padding(12)
        .background(Material.thin.opacity(0.95))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.15), radius: 8)
        .onDisappear {
            // 视图销毁时禁用动画
            isActive = false
            
            // 强制主线程执行
            DispatchQueue.main.async {
                print("🧹 [RecordingIndicatorView] onDisappear - 视图已销毁")
            }
        }
    }
    
    // MARK: - Recording Indicator
    
    // 紧凑的录音视图（带电平表）
    private var compactRecordingView: some View {
        VStack(spacing: 6) {
            // 上方：状态和时间
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                
                Text("REC")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(timeString(audioRecorder.recordingDuration))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            // 下方：电平表
            compactAudioLevelMeter
        }
    }
    
    // 紧凑的转写视图
    private var compactTranscribingView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.7)
            
            Text("识别中...")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // 紧凑的电平表
    private var compactAudioLevelMeter: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.2))
                
                // 电平条
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [.green, .yellow, .orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geometry.size.width * CGFloat(audioRecorder.audioLevel)))
                
                // 简化的零输入提示
                if audioRecorder.audioLevel < 0.01 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 8))
                        Text("无声音")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: 8)
        .animation(isActive ? .linear(duration: 0.1) : nil, value: audioRecorder.audioLevel)
    }
    
    // 紧凑的错误视图
    private func compactErrorView(_ error: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 10))
                .foregroundColor(.orange)
            
            Text(error)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
    
    private var recordingIndicator: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.red)
                .frame(width: 16, height: 16)
                .overlay(
                    Circle()
                        .stroke(Color.red.opacity(0.3), lineWidth: 5)
                        .scaleEffect(1.5)
                        .opacity(0.8)
                        .animation(
                            .easeInOut(duration: 1)
                            .repeatForever(autoreverses: true),
                            value: coordinator.isRecording
                        )
                )
            
            Text("recording")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(timeString(audioRecorder.recordingDuration))
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Transcribing Indicator
    
    private var transcribingIndicator: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.0)
            
            Text("transcribing")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Audio Level Meter
    
    private var audioLevelMeter: some View {
        VStack(spacing: 8) {
            // 电平标签和数值
            HStack {
                Text("音频电平")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(String(format: "%.0f%%", audioRecorder.audioLevel * 100))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(audioRecorder.audioLevel > 0.1 ? .green : .orange)
            }
            
            // 电平条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                    
                    // 电平条
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [.green, .yellow, .orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geometry.size.width * CGFloat(audioRecorder.audioLevel)))
                    
                    // 提示文字（当电平为0时）
                    if audioRecorder.audioLevel < 0.01 {
                        Text("⚠️ 未检测到声音输入")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: 12)
            .animation(isActive ? .linear(duration: 0.1) : nil, value: audioRecorder.audioLevel)
        }
    }
    
    // MARK: - Text Preview
    
    private var textPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("transcribed_text")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Text(coordinator.currentText)
                .font(.body)
                .fontWeight(.regular)
                .foregroundColor(.primary)
                .lineLimit(5)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }
    
    // MARK: - Error View
    
    private func errorView(_ error: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundColor(.orange)
            
            Text(error)
                .font(.callout)
                .foregroundColor(.secondary)
                .lineLimit(2)
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
