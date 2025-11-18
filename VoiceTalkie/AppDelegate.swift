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
    private var settingsPanel: NSPanel?  // 🔑 改为 NSPanel
    private var recordingIndicatorWindow: RecordingIndicatorWindow?
    
    // 录音状态通知观察者（可选优化：方便在销毁时移除）
    private var recordingStateObserver: NSObjectProtocol?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 创建菜单栏图标
        setupStatusBarItem()
        
        // 创建录音指示器窗口
        recordingIndicatorWindow = RecordingIndicatorWindow()
        
        // 隐藏 Dock 图标
        NSApp.setActivationPolicy(.accessory)
        
        // 初始化协调器
        Task {
            await coordinator.initialize()
        }
        
        // 监听录音状态变化
        observeCoordinatorState()
    }
    
    deinit {
        // 清理录音状态观察者（防止潜在泄漏/野指针）
        if let observer = recordingStateObserver {
            NotificationCenter.default.removeObserver(observer)
            recordingStateObserver = nil
        }
    }
    
    // MARK: - 状态栏菜单
    
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
        let startItem = NSMenuItem(
            title: NSLocalizedString("start_recording", comment: "Start Recording"),
            action: #selector(startRecording),
            keyEquivalent: ""
        )
        startItem.target = self
        menu.addItem(startItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 设置菜单项
        let settingsItem = NSMenuItem(
            title: NSLocalizedString("settings", comment: "Settings"),
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 退出菜单项
        let quitItem = NSMenuItem(
            title: NSLocalizedString("quit", comment: "Quit VoiceTalkie"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    // MARK: - 菜单动作
    
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
        // 如果设置面板已存在且可见，直接显示
        if let panel = settingsPanel {
            if panel.isVisible {
                panel.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            } else {
                // 面板存在但不可见，说明已关闭，清理引用
                settingsPanel = nil
            }
        }
        
        // 创建设置视图
        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)
        
        // 🔑 关键：使用 NSPanel 而不是 NSWindow
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 650),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        panel.title = NSLocalizedString("settings_title", comment: "VoiceTalkie Settings")
        panel.contentViewController = hostingController
        panel.center()
        panel.isFloatingPanel = false
        panel.becomesKeyOnlyIfNeeded = false
        
        // 监听面板关闭事件
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            // 延迟清理引用
            DispatchQueue.main.async {
                self?.settingsPanel = nil
            }
        }
        
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        settingsPanel = panel
    }
    
    // MARK: - Coordinator State Observation
    
    private func observeCoordinatorState() {
        // 如果之前已经有观察者，先移除
        if let observer = recordingStateObserver {
            NotificationCenter.default.removeObserver(observer)
            recordingStateObserver = nil
        }
        
        // 观察录音状态变化
        recordingStateObserver = NotificationCenter.default.addObserver(
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
                guard let self = self else { return }
                if !self.coordinator.isRecording && !self.coordinator.isTranscribing {
                    self.recordingIndicatorWindow?.hide()
                }
            }
        } else {
            recordingIndicatorWindow?.hide()
        }
    }
}
