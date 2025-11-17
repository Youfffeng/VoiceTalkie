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

/// Service for managing app permissions
class PermissionService: ObservableObject {
    static let shared = PermissionService()
    
    @Published var microphonePermissionGranted = false
    @Published var speechRecognitionPermissionGranted = false
    @Published var accessibilityPermissionGranted = false
    @Published var inputMonitoringPermissionGranted = false
    
    private init() {
        checkAllPermissions()
    }
    
    // MARK: - Check All Permissions
    
    func checkAllPermissions() {
        checkMicrophonePermission()
        checkSpeechRecognitionPermission()
        checkAccessibilityPermission()
        checkInputMonitoringPermission()
    }
    
    // MARK: - Microphone Permission
    
    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    self.microphonePermissionGranted = granted
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    func checkMicrophonePermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        DispatchQueue.main.async {
            self.microphonePermissionGranted = (status == .authorized)
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
