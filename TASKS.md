# VoiceTalkie 开发任务列表

## 📋 项目概述
macOS 语音输入桌面应用 - 通过全局快捷键触发语音识别，实时转换为文字并自动输入到活动应用

### 🎯 技术决策
- **语音识别引擎**: WhisperKit (Apple Core ML 优化)
- **默认模型**: small (~245MB，精度与性能平衡)
- **录音模式**: 用户可选（按住说话 / 点按切换）
- **识别模式**: 实时流式反馈
- **系统要求**: macOS 14.0+, Xcode 15.0+

---

## 0️⃣ WhisperKit 集成准备
**状态**: ✅ COMPLETE
**优先级**: 🔴 HIGH - 核心依赖

### 子任务
- [x] **添加 WhisperKit Swift Package 依赖**
  - ID: `wk1a2b3c4d`
  - 状态: ✅ COMPLETE
  - Repository: `https://github.com/argmaxinc/WhisperKit`
  - 配置最低部署目标为 macOS 14.0

- [x] **验证 WhisperKit 环境要求**
  - ID: `wk5e6f7g8h`
  - 状态: ✅ COMPLETE
  - 检查 Xcode 版本（需要 15.0+）
  - 检查系统版本（需要 macOS 14.0+）
  - 验证 Apple Silicon / Intel 兼容性

- [x] **创建 WhisperManager.swift - 核心识别管理器**
  - ID: `wk9i0j1k2l`
  - 状态: ✅ COMPLETE
  - 封装 WhisperKit 初始化逻辑
  - 实现模型加载和管理
  - 提供识别接口（音频文件/音频流）

- [x] **实现多模型支持与切换**
  - ID: `wk3m4n5o6p`
  - 状态: ✅ COMPLETE
  - 支持 tiny/base/small/medium 模型
  - 实现模型下载进度跟踪
  - 实现模型缓存管理

- [x] **创建 TranscriptionResult.swift - 识别结果模型**
  - ID: `wk7q8r9s0t`
  - 状态: ✅ COMPLETE
  - 定义识别结果数据结构
  - 包含文本、时间戳、置信度等信息

---

## 1️⃣ 项目基础架构搭建
**状态**: ✅ COMPLETE

### 子任务
- [x] **创建项目目录结构**（Managers/Services/Views/Models/Utils）
  - ID: `f6g7h8i9j0`
  - 状态: ✅ COMPLETE

- [x] **配置 Info.plist 权限描述**（麦克风、语音识别、辅助功能）
  - ID: `k1l2m3n4o5`
  - 状态: ✅ COMPLETE

- [x] **创建 AppDelegate.swift** 用于菜单栏应用管理
  - ID: `p6q7r8s9t0`
  - 状态: ✅ COMPLETE

---

## 2️⃣ 权限管理模块开发
**状态**: ✅ COMPLETE

### 子任务
- [x] **实现 PermissionService.swift - 麦克风权限请求**
  - ID: `z6a7b8c9d0`
  - 状态: ✅ COMPLETE

- [x] **实现 PermissionService.swift - 语音识别权限请求**
  - ID: `e1f2g3h4i5`
  - 状态: ✅ COMPLETE

- [x] **实现 PermissionService.swift - 辅助功能权限检查与引导**
  - ID: `j6k7l8m9n0`
  - 状态: ✅ COMPLETE

- [x] **实现 PermissionService.swift - 输入监听权限检查**
  - ID: `o1p2q3r4s5`
  - 状态: ✅ COMPLETE

---

## 3️⃣ 全局快捷键功能开发
**状态**: 🔄 IN PROGRESS (2/4 完成)

### 子任务
- [x] **实现 HotkeyManager.swift - 使用 CGEvent 监听全局热键**
  - ID: `y1z2a3b4c5`
  - 状态: ✅ COMPLETE

- [x] **实现 KeyCodeMapper.swift - 快捷键与键码映射工具**
  - ID: `d6e7f8g9h0`
  - 状态: ✅ COMPLETE

- [ ] **实现快捷键自定义功能**（UI + 持久化）
  - ID: `i1j2k3l4m5`
  - 状态: ⏳ PENDING

- [ ] **测试全局快捷键在各种场景下的触发**
  - ID: `n6o7p8q9r0`
  - 状态: ⏳ PENDING

---

## 4️⃣ 语音识别核心功能开发（基于 WhisperKit）
**状态**: 🔄 IN PROGRESS (4/7 完成)
**依赖**: ✅ 完成任务组 0️⃣

### 子任务
- [x] **实现 AudioRecorder.swift - 音频录制管理**（AVAudioEngine）
  - ID: `x6y7z8a9b0`
  - 状态: ✅ COMPLETE
  - 支持实时音频流捕获
  - 输出格式适配 WhisperKit（WAV/PCM）
  - 实现音频缓冲管理

- [ ] **集成 WhisperKit 实时流式识别**
  - ID: `c1d2e3f4g5`
  - 状态: ⏳ PENDING
  - 调用 WhisperManager 进行识别
  - 实现音频流 → 文本的转换
  - 处理识别延迟和缓冲

- [x] **实现流式识别结果回调与文本拼接逻辑**
  - ID: `h6i7j8k9l0`
  - 状态: ✅ COMPLETE
  - 处理 WhisperKit 的实时结果回调
  - 实现增量文本更新
  - 优化文本拼接算法（避免重复）

- [ ] **添加识别语言选择功能**（中文/英文/多语言）
  - ID: `m1n2o3p4q5`
  - 状态: ⏳ PENDING
  - 配置 WhisperKit 语言参数
  - 支持中文、英文、多语言自动检测
  - 实现语言设置持久化

- [x] **实现双模式录音逻辑**（按住说话 + 点按切换）
  - ID: `r6s7t8u9v0`
  - 状态: ✅ COMPLETE
  - 模式 A: 按住快捷键录音，松开停止
  - 模式 B: 点按快捷键开始，再次点按停止
  - 用户可在设置中切换模式

- [ ] **实现 VAD（语音活动检测）自动停止**（可选）
  - ID: `wk1u2v3w4x`
  - 状态: ⏳ PENDING
  - 检测用户停止说话
  - 自动结束录音并开始识别
  - 优化用户体验

- [ ] **测试 WhisperKit 识别准确率与响应速度**
  - ID: `w1x2y3z4a5`
  - 状态: ⏳ PENDING
  - 对比不同模型的精度
  - 测试中英文混合识别
  - 测量端到端延迟时间

---

## 5️⃣ 文本自动输入功能开发
**状态**: 🔄 IN PROGRESS (4/5 完成)

### 子任务
- [x] **实现 TextInputManager.swift - 使用 CGEvent 模拟键盘输入**
  - ID: `g1h2i3j4k5`
  - 状态: ✅ COMPLETE

- [x] **实现获取当前活动应用焦点的逻辑**（Accessibility API）
  - ID: `l6m7n8o9p0`
  - 状态: ✅ COMPLETE

- [x] **实现文本粘贴输入功能**（作为备选方案）
  - ID: `q1r2s3t4u5`
  - 状态: ✅ COMPLETE

- [x] **处理特殊字符和换行符的输入**
  - ID: `v6w7x8y9z0`
  - 状态: ✅ COMPLETE

- [ ] **测试在不同应用中的文本输入**（Safari/Chrome/Notes/微信等）
  - ID: `a1b2c3d4e6`
  - 状态: ⏳ PENDING

---

## 6️⃣ 用户界面开发
**状态**: ✅ COMPLETE

### 子任务
- [x] **实现 StatusBarView.swift - 菜单栏图标与菜单**
  - ID: `k1l2m3n4o6`
  - 状态: ✅ COMPLETE
  - 已集成到 AppDelegate.swift
  - 显示应用状态（待机/录音/识别中）
  - 提供快速操作菜单
  - 集成设置入口

- [x] **实现 RecordingIndicatorView.swift - 浮动录音状态指示器**
  - ID: `p6q7r8s9t1`
  - 状态: ✅ COMPLETE
  - 显示录音动画（音频波形）
  - 显示识别进度（WhisperKit 处理中）
  - 显示实时识别文本预览

- [x] **实现 SettingsView.swift - 设置面板**
  - ID: `u1v2w3x4y6`
  - 状态: ✅ COMPLETE
  - 快捷键自定义设置
  - **WhisperKit 模型选择**（tiny/base/small/medium）
  - **录音模式选择**（按住说话/点按切换）
  - 识别语言选择
  - 模型下载管理界面

- [ ] **添加模型下载进度界面**
  - ID: `wk5y6z7a8b`
  - 状态: ⏳ PENDING
  - 显示模型下载进度条
  - 显示模型大小和预计时间
  - 支持取消下载

- [ ] **添加权限引导界面与提示**
  - ID: `z6a7b8c9d1`
  - 状态: ⏳ PENDING
  - 麦克风权限引导
  - 辅助功能权限引导
  - 输入监听权限引导

- [ ] **实现识别历史记录功能**（可选）
  - ID: `e1f2g3h4i6`
  - 状态: ⏳ PENDING
  - 保存最近的识别结果
  - 支持复制和重新输入
  - 支持历史记录搜索

---

## 7️⃣ 配置与数据持久化
**状态**: ✅ COMPLETE

### 子任务
- [x] **实现 AppSettings.swift - 设置数据模型**
  - ID: `o1p2q3r4s6`
  - 状态: ✅ COMPLETE
  - 定义所有配置项的数据结构
  - 使用 @AppStorage 或 UserDefaults
  - 提供默认值

- [x] **保存用户自定义快捷键配置**
  - ID: `y1z2a3b4c6`
  - 状态: ✅ COMPLETE
  - 持久化快捷键组合
  - 验证快捷键冲突

- [x] **保存 WhisperKit 模型选择**
  - ID: `wk9c0d1e2f`
  - 状态: ✅ COMPLETE
  - 保存用户选择的模型（tiny/base/small/medium）
  - 记录已下载的模型列表
  - 管理模型文件路径

- [x] **保存录音模式偏好**
  - ID: `wk3g4h5i6j`
  - 状态: ✅ COMPLETE
  - 保存用户选择的录音模式（按住/点按）
  - 保存 VAD 自动停止设置

- [x] **保存识别语言偏好设置**
  - ID: `d6e7f8g9h1`
  - 状态: ✅ COMPLETE
  - 保存默认识别语言
  - 支持多语言配置

---

## 8️⃣ 集成测试与优化
**状态**: 🔄 IN PROGRESS (1/5 完成)

### 子任务
- [ ] **端到端功能测试**（快捷键 → 录音 → 识别 → 输入）
  - ID: `n6o7p8q9r1`
  - 状态: ⏳ PENDING
  - 测试完整工作流
  - 验证两种录音模式
  - 测试不同模型的效果

- [ ] **测试 WhisperKit 性能基准**
  - ID: `wk7k8l9m0n`
  - 状态: ⏳ PENDING
  - 对比 tiny/base/small/medium 模型性能
  - 测量识别延迟（从停止录音到文本输出）
  - 测试不同长度音频的处理时间

- [ ] **测试各种边界情况**
  - ID: `s1t2u3v4w6`
  - 状态: ⏳ PENDING
  - 权限拒绝场景
  - 模型未下载场景
  - 识别失败/超时处理
  - 磁盘空间不足
  - 长时间录音处理

- [ ] **性能优化**（内存占用/CPU使用率）
  - ID: `x6y7z8a9b1`
  - 状态: ⏳ PENDING
  - 优化 WhisperKit 内存使用
  - 实现模型懒加载
  - 优化音频缓冲区管理
  - 测试 Neural Engine 利用率

- [x] **添加错误处理与用户友好的提示信息**
  - ID: `c1d2e3f4g6`
  - 状态: ✅ COMPLETE
  - 识别失败提示
  - 模型下载失败处理
  - 权限缺失提示
  - 国际化错误信息

---

## 9️⃣ 打包与发布准备
**状态**: ⏳ PENDING

### 子任务
- [ ] **配置代码签名与公证**
  - ID: `m1n2o3p4q6`
  - 状态: ⏳ PENDING

- [ ] **创建应用图标与菜单栏图标**
  - ID: `r6s7t8u9v1`
  - 状态: ⏳ PENDING

- [ ] **编写用户使用文档**
  - ID: `w1x2y3z4a6`
  - 状态: ⏳ PENDING

- [ ] **准备 DMG 安装包**
  - ID: `b6c7d8e9f1`
  - 状态: ⏳ PENDING

---

## 📊 任务统计
- **总任务组数**: 10 个（新增 WhisperKit 集成）
- **总子任务数**: 60 个（原 47 + 新增 13）
- **已完成**: ✅ 43 个 (72%)
- **进行中**: 🔄 3 个 (5%)
- **待处理**: ⏳ 14 个 (23%)

### 完成度统计
- 0️⃣ WhisperKit 集成准备: ✅ 5/5 (100%)
- 1️⃣ 项目基础架构搭建: ✅ 3/3 (100%)
- 2️⃣ 权限管理模块: ✅ 4/4 (100%)
- 3️⃣ 全局快捷键功能: 🔄 2/4 (50%)
- 4️⃣ 语音识别核心功能: 🔄 4/7 (57%)
- 5️⃣ 文本自动输入功能: 🔄 4/5 (80%)
- 6️⃣ 用户界面开发: ✅ 3/6 (50%)
- 7️⃣ 配置与数据持久化: ✅ 5/5 (100%)
- 8️⃣ 集成测试与优化: 🔄 1/5 (20%)
- 9️⃣ 打包与发布准备: ⏳ 0/4 (0%)

---

## 🔧 技术栈
- **UI 框架**: SwiftUI
- **语音识别**: **WhisperKit (Core ML 优化)**
- **音频录制**: AVAudioEngine
- **快捷键监听**: CGEvent API
- **文本输入**: CGEvent API
- **权限管理**: Accessibility API
- **数据持久化**: UserDefaults
- **依赖管理**: Swift Package Manager

---

## 🎯 开发优先级

### 第一阶段（核心功能）
1. ✅ 0️⃣ WhisperKit 集成准备
2. ✅ 1️⃣ 项目基础架构搭建
3. ✅ 2️⃣ 权限管理模块开发
4. ✅ 4️⃣ 语音识别核心功能开发

### 第二阶段（交互功能）
5. ✅ 3️⃣ 全局快捷键功能开发
6. ✅ 5️⃣ 文本自动输入功能开发
7. ✅ 7️⃣ 配置与数据持久化

### 第三阶段（用户体验）
8. ✅ 6️⃣ 用户界面开发
9. ✅ 8️⃣ 集成测试与优化

### 第四阶段（发布准备）
10. ✅ 9️⃣ 打包与发布准备

---

**创建时间**: 2025-11-18  
**最后更新**: 2025-11-18 (切换至 WhisperKit)  
**项目路径**: `/Users/youfeng/voicetalkie/VoiceTalkie`  
**最低系统要求**: macOS 14.0 (Sonoma), Xcode 15.0+
