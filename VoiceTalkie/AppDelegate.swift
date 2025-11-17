//
//  AppDelegate.swift
//  VoiceTalkie
//
//  Created by Qoder on 11/18/25.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let coordinator = VoiceTalkieCoordinator.shared
    private var settingsWindow: NSWindow?
    private var recordingIndicatorWindow: RecordingIndicatorWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 创建菜单栏图标
        setupStatusBarItem()
        
        // 创建录音指示器窗口
        recordingIndicatorWindow = RecordingIndicatorWindow()
        
        // 隐藏 Dock 图标（可选，如果只想要菜单栏应用）
        NSApp.setActivationPolicy(.accessory)
        
        // 初始化协调器
        Task {
            await coordinator.initialize()
        }
        
        // 监听录音状态变化，显示/隐藏指示器
        observeCoordinatorState()
    }
    
    private func setupStatusBarItem() {
        // 创建状态栏项目
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let button = statusItem?.button else {
            print("Failed to create status bar button")
            return
        }
        
        // 设置图标（暂时使用 SF Symbol）
        if let image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Voice Talkie") {
            image.isTemplate = true
            button.image = image
        }
        
        // 创建菜单
        let menu = NSMenu()
        
        // 开始录音菜单项
        menu.addItem(NSMenuItem(
            title: NSLocalizedString("start_recording", comment: "Start Recording"),
            action: #selector(startRecording),
            keyEquivalent: ""
        ))
        
        menu.addItem(NSMenuItem.separator())
        
        // 设置菜单项
        menu.addItem(NSMenuItem(
            title: NSLocalizedString("settings", comment: "Settings"),
            action: #selector(openSettings),
            keyEquivalent: ","
        ))
        
        menu.addItem(NSMenuItem.separator())
        
        // 退出菜单项
        menu.addItem(NSMenuItem(
            title: NSLocalizedString("quit", comment: "Quit VoiceTalkie"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        
        statusItem?.menu = menu
    }
    
    @objc private func startRecording() {
        Task {
            if coordinator.isRecording {
                await coordinator.manualStopRecording()
            } else {
                await coordinator.manualStartRecording()
            }
        }
    }
    
    @objc private func openSettings() {
        // 如果设置窗口已存在，直接显示
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // 创建设置窗口
        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = NSLocalizedString("settings_title", comment: "VoiceTalkie Settings")
        window.contentViewController = hostingController
        window.center()
        window.makeKeyAndOrderFront(nil)
        
        // 激活应用
        NSApp.activate(ignoringOtherApps: true)
        
        settingsWindow = window
    }
    
    // MARK: - Coordinator State Observation
    
    private func observeCoordinatorState() {
        // 观察录音状态
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("VoiceTalkieRecordingStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateIndicatorVisibility()
        }
    }
    
    private func updateIndicatorVisibility() {
        if coordinator.isRecording || coordinator.isTranscribing {
            recordingIndicatorWindow?.show()
        } else if !coordinator.currentText.isEmpty {
            // 显示识别结果 2 秒后隐藏
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                if !(self?.coordinator.isRecording ?? false) && !(self?.coordinator.isTranscribing ?? false) {
                    self?.recordingIndicatorWindow?.hide()
                }
            }
        } else {
            recordingIndicatorWindow?.hide()
        }
    }
}
