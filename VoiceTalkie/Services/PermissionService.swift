//
//  PermissionService.swift
//  VoiceTalkie
//
//  Created by Qoder on 11/18/25.
//

import Foundation
import AVFoundation
import Speech
import ApplicationServices
import Combine
import AppKit

/// Service for managing app permissions
class PermissionService: ObservableObject {
    static let shared = PermissionService()
    
    @Published var microphonePermissionGranted = false
    @Published var speechRecognitionPermissionGranted = false
    @Published var accessibilityPermissionGranted = false
    @Published var inputMonitoringPermissionGranted = false
    private var micPromptShown = false  // 本次运行仅提示一次
    
    private init() {
        checkAllPermissions()
    }
    
    // MARK: - Check All Permissions
    
    func checkAllPermissions() {
        checkMicrophonePermission()
        checkSpeechRecognitionPermission()
        _ = checkAccessibilityPermission()
        _ = checkInputMonitoringPermission()
    }
    
    // MARK: - Microphone Permission
    
    func requestMicrophonePermission() async -> Bool {
        #if os(macOS)
        // macOS 使用 AVCaptureDevice
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .notDetermined {
            return await AVCaptureDevice.requestAccess(for: .audio)
        }
        return status == .authorized
        #else
        // iOS 使用 AVAudioApplication
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    self.microphonePermissionGranted = granted
                    continuation.resume(returning: granted)
                }
            }
        }
        #endif
    }
    
    func checkMicrophonePermission() {
        // macOS 使用 AVCaptureDevice 检查麦克风权限
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        DispatchQueue.main.async {
            self.microphonePermissionGranted = (status == .authorized)
        }
    }
    
    // 统一的麦克风权限保证方法：仅在未确定时请求一次；拒绝时只提示一次并引导到系统设置
    func ensureMicrophoneAuthorized() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        print("🎤 [PermissionService] Current microphone permission status: \(status.rawValue)")
        print("   - 0 = notDetermined, 1 = restricted, 2 = denied, 3 = authorized")
        
        switch status {
        case .authorized:
            DispatchQueue.main.async { self.microphonePermissionGranted = true }
            return true
        case .notDetermined:
            print("⚠️ [PermissionService] Permission not determined, requesting...")
            let granted = await requestMicrophonePermission()
            print("📊 [PermissionService] Request result: \(granted ? "Granted" : "Denied")")
            return granted
        case .denied:
            print("❌ [PermissionService] Permission denied")
            if !micPromptShown {
                micPromptShown = true
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "需要麦克风权限"
                    alert.informativeText = "请到 系统设置 → 隐私与安全性 → 麦克风 中允许 VoiceTalkie 访问麦克风。"
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "打开系统设置")
                    alert.addButton(withTitle: "取消")
                    if alert.runModal() == .alertFirstButtonReturn {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
            DispatchQueue.main.async { self.microphonePermissionGranted = false }
            return false
        @unknown default:
            print("⚠️ [PermissionService] Unknown permission status")
            DispatchQueue.main.async { self.microphonePermissionGranted = false }
            return false
        }
    }
    
    // MARK: - Speech Recognition Permission
    
    func requestSpeechRecognitionPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { authStatus in
                DispatchQueue.main.async {
                    let granted = (authStatus == .authorized)
                    self.speechRecognitionPermissionGranted = granted
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    func checkSpeechRecognitionPermission() {
        let status = SFSpeechRecognizer.authorizationStatus()
        DispatchQueue.main.async {
            self.speechRecognitionPermissionGranted = (status == .authorized)
        }
    }
    
    // MARK: - Accessibility Permission
    
    func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        DispatchQueue.main.async {
            self.accessibilityPermissionGranted = accessEnabled
        }
        
        return accessEnabled
    }
    
    func promptAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
    
    // MARK: - Input Monitoring Permission
    
    func checkInputMonitoringPermission() -> Bool {
        // 在 macOS 10.15+ 需要显式请求输入监听权限
        // 检查是否可以创建事件监听器
        let canMonitor = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
        
        DispatchQueue.main.async {
            self.inputMonitoringPermissionGranted = canMonitor
        }
        
        return canMonitor
    }
    
    func promptInputMonitoringPermission() {
        // 尝试请求权限
        let _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }
    
    func openInputMonitoringSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        NSWorkspace.shared.open(url)
    }
    
    // MARK: - All Permissions Check
    
    func areAllPermissionsGranted() -> Bool {
        return microphonePermissionGranted &&
               speechRecognitionPermissionGranted &&
               accessibilityPermissionGranted &&
               inputMonitoringPermissionGranted
    }
    
    func requestAllPermissions() async {
        // Request microphone permission
        _ = await requestMicrophonePermission()
        
        // Request speech recognition permission
        _ = await requestSpeechRecognitionPermission()
        
        // Prompt for accessibility permission (system dialog)
        promptAccessibilityPermission()
        
        // Prompt for input monitoring permission
        promptInputMonitoringPermission()
        
        // Recheck after a short delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        checkAllPermissions()
    }
}
