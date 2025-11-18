# 🎤 VoiceTalkie - 本地模型集成

## 🚀 快速开始

### 一键下载模型

```bash
cd /Users/youfeng/voicetalkie/VoiceTalkie
./download_models.sh
```

按提示选择要下载的模型（推荐选择 `3. small`）。

---

## 📦 将模型添加到 Xcode

### 方法 1：拖拽添加（推荐）

1. **打开 Xcode 项目**
   ```bash
   open VoiceTalkie.xcodeproj
   ```

2. **创建 Models 组**
   - 在左侧导航器中右键点击 `VoiceTalkie`
   - 选择 `New Group`
   - 命名为 `Models`

3. **拖入模型文件夹**
   - 打开 Finder，定位到 `WhisperModels/openai_whisper-small/`
   - 拖拽整个 `openai_whisper-small` 文件夹到 Xcode 的 `Models` 组

4. **配置导入选项**（重要！）
   - ✅ **Copy items if needed**
   - ✅ **Create folder references** （蓝色文件夹图标）
   - ✅ **Add to targets: VoiceTalkie**
   - ❌ ~~Create groups~~（不要选这个！）

5. **验证**
   - 文件夹应该显示为**蓝色**图标
   - 点击文件夹，右侧应显示所有 `.mlmodelc` 文件

---

## ✅ 验证集成成功

### 编译测试

```bash
cd /Users/youfeng/voicetalkie/VoiceTalkie
xcodebuild -project VoiceTalkie.xcodeproj -scheme VoiceTalkie build
```

如果看到 `** BUILD SUCCEEDED **`，说明集成成功！

### 运行应用检查

1. **运行应用**：Xcode → Product → Run (⌘R)

2. **打开设置**：点击菜单栏图标 → 设置

3. **检查模型状态**：
   - 在 "识别模型" 部分
   - `small` 模型旁边应该显示 **✅ 本地**
   - 底部显示 **✅ 当前模型已在本地，无需下载**

4. **查看控制台日志**：
   ```
   📦 [WhisperManager] 找到Bundle中的模型
   ✅ [WhisperManager] 使用本地模型初始化成功: small
   ```

---

## 📊 模型对比

| 模型 | 大小 | 内存占用 | 速度 | 精度 | 推荐场景 |
|------|------|----------|------|------|----------|
| tiny | 75 MB | ~200 MB | ⚡⚡⚡⚡⚡ | ⭐⭐ | 测试/演示 |
| base | 145 MB | ~350 MB | ⚡⚡⚡⚡ | ⭐⭐⭐ | 日常使用 |
| **small** | **245 MB** | **~500 MB** | **⚡⚡⚡** | **⭐⭐⭐⭐** | **推荐** |
| medium | 769 MB | ~1.5 GB | ⚡⚡ | ⭐⭐⭐⭐⭐ | 高精度 |
| large-v3 | 1.5 GB | ~3 GB | ⚡ | ⭐⭐⭐⭐⭐ | 专业用途 |

---

## 🎯 工作原理

应用启动时，WhisperManager 会按以下优先级查找模型：

```
1️⃣ ~/Library/Application Support/whisperkit-models/
   ↓ (不存在)
   
2️⃣ App Bundle 内置模型
   ↓ (找到！)
   
3️⃣ 复制到 Application Support
   ↓
   
4️⃣ 加载并使用
```

首次运行时，会将 Bundle 中的模型复制到 Application Support 目录，后续直接使用缓存。

---

## 🔧 常见问题

### Q1: 模型仍然显示"需下载"？

**检查清单**：
- [ ] 文件夹名称是 `openai_whisper-{model_name}`
- [ ] 使用了 **folder references**（蓝色图标）
- [ ] 文件夹在 Build Phases → Copy Bundle Resources 中

**解决方法**：
```bash
# 删除并重新添加
rm -rf VoiceTalkie/Models
# 重新拖拽，确保选择 "Create folder references"
```

### Q2: 编译后应用体积很大？

这是正常的！模型文件会被打包到应用中：
- `tiny`: +75 MB
- `small`: +245 MB
- `medium`: +769 MB

**优化建议**：
- 只打包一个最常用的模型
- 其他模型让用户按需下载

### Q3: 如何更新模型？

```bash
cd WhisperModels
git pull origin main
# 重新拖拽到 Xcode
```

### Q4: 可以支持多个模型吗？

可以！添加多个模型文件夹：
```
Models/
├── openai_whisper-tiny/
├── openai_whisper-small/
└── openai_whisper-medium/
```

应用会根据用户选择自动使用对应模型。

---

## 📝 完整文档

详细说明请参考：**[MODEL_INTEGRATION_GUIDE.md](MODEL_INTEGRATION_GUIDE.md)**

---

## 🎉 完成！

集成成功后，你的应用将：
- ✅ 无需网络即可使用
- ✅ 首次启动速度快
- ✅ 离线环境下正常工作
- ✅ 减少用户等待时间

**开始使用吧！** 🚀
