//
//  RecordingIndicatorWindow.swift
//  VoiceTalkie
//
//  Created by Qoder on 11/18/25.
//

import SwiftUI
import AppKit

/// Floating window that displays recording status
class RecordingIndicatorWindow: NSPanel {
    private var hostingView: NSHostingView<RecordingIndicatorView>?
    
    init() {
        // Create compact floating window
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 70),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // Configure window
        self.isFloatingPanel = true
        self.level = .floating
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Create SwiftUI view
        let contentView = RecordingIndicatorView()
        hostingView = NSHostingView(rootView: contentView)
        self.contentView = hostingView
        
        // 🎯 初始化时先隐藏窗口，等待 show() 时再定位
        self.alphaValue = 0.0
    }
    
    /// Show the indicator window
    func show() {
        // 📍 获取当前光标位置，将窗口定位到输入框附近
        positionNearCursor()
        
        self.orderFrontRegardless()
        // 不要让窗口成为 key window，避免影响用户输入
        // self.makeKey()
        
        // Animate in
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            self.animator().alphaValue = 1.0
        })
    }
    
    /// 🎯 将窗口定位到当前输入框附近
    private func positionNearCursor() {
        // 📝 尝试获取当前焦点元素（文本输入框）的位置
        if let inputFieldPosition = getFocusedTextFieldPosition() {
            positionNearInputField(inputFieldPosition)
        } else {
            // 如果无法获取输入框位置，使用光标位置作为后备
            positionNearMouse()
        }
    }
    
    /// 📍 获取当前焦点文本输入框的位置
    private func getFocusedTextFieldPosition() -> NSRect? {
        // 获取系统级的焦点元素
        let systemWideElement = AXUIElementCreateSystemWide()
        
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )
        
        guard result == .success,
              let element = focusedElement else {
            return nil
        }
        
        // 获取元素的位置和尺寸
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        
        let posResult = AXUIElementCopyAttributeValue(
            element as! AXUIElement,
            kAXPositionAttribute as CFString,
            &positionValue
        )
        
        let sizeResult = AXUIElementCopyAttributeValue(
            element as! AXUIElement,
            kAXSizeAttribute as CFString,
            &sizeValue
        )
        
        guard posResult == .success,
              sizeResult == .success,
              let posValue = positionValue,
              let szValue = sizeValue else {
            return nil
        }
        
        // 解析 AXValue 到 CGPoint 和 CGSize
        var position = CGPoint.zero
        var size = CGSize.zero
        
        AXValueGetValue(posValue as! AXValue, .cgPoint, &position)
        AXValueGetValue(szValue as! AXValue, .cgSize, &size)
        
        // 转换到屏幕坐标（macOS 坐标系原点在左下）
        if let screen = NSScreen.main {
            let screenHeight = screen.frame.height
            // AX API 返回的 y 坐标是从屏幕顶部开始，需要转换
            let flippedY = screenHeight - position.y - size.height
            return NSRect(x: position.x, y: flippedY, width: size.width, height: size.height)
        }
        
        return NSRect(x: position.x, y: position.y, width: size.width, height: size.height)
    }
    
    /// 📋 根据输入框位置计算窗口位置
    private func positionNearInputField(_ inputFieldRect: NSRect) {
        let windowRect = self.frame
        
        // 默认显示在输入框左下方
        var targetX = inputFieldRect.minX
        var targetY = inputFieldRect.minY - windowRect.height - 10  // 输入框下方 10pt
        
        // 确保窗口在屏幕范围内
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            
            // 水平边界检查
            if targetX + windowRect.width > screenRect.maxX {
                // 如果右侧空间不够，尝试左对齐输入框右侧
                targetX = inputFieldRect.maxX - windowRect.width
            }
            if targetX < screenRect.minX {
                targetX = screenRect.minX + 10
            }
            
            // 垂直边界检查
            if targetY < screenRect.minY {
                // 如果下方空间不够，显示在输入框上方
                targetY = inputFieldRect.maxY + 10
            }
            if targetY + windowRect.height > screenRect.maxY {
                targetY = screenRect.maxY - windowRect.height - 10
            }
        }
        
        self.setFrameOrigin(NSPoint(x: targetX, y: targetY))
    }
    
    /// 🐭 后备方案：使用鼠标位置
    private func positionNearMouse() {
        // 获取当前鼠标位置
        let mousePosition = NSEvent.mouseLocation
        
        // 窗口尺寸
        let windowRect = self.frame
        
        // 计算目标位置：鼠标左下方
        var targetX = mousePosition.x - 20
        var targetY = mousePosition.y - windowRect.height - 10
        
        // 确保窗口在屏幕范围内
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            
            // 水平边界检查
            if targetX + windowRect.width > screenRect.maxX {
                targetX = screenRect.maxX - windowRect.width - 20
            }
            if targetX < screenRect.minX {
                targetX = screenRect.minX + 20
            }
            
            // 垂直边界检查
            if targetY < screenRect.minY {
                // 如果下方空间不够，显示在鼠标上方
                targetY = mousePosition.y + 10
            }
            if targetY + windowRect.height > screenRect.maxY {
                targetY = screenRect.maxY - windowRect.height - 20
            }
        }
        
        self.setFrameOrigin(NSPoint(x: targetX, y: targetY))
    }
    
    /// Hide the indicator window
    func hide() {
        // Animate out
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            self.animator().alphaValue = 0.0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }
    
    /// Update window position (call when screen layout changes)
    func updatePosition() {
        // 重新定位到当前光标附近
        positionNearCursor()
    }
}
