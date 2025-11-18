#!/bin/bash

# WhisperKit 模型下载脚本
# 用途：自动下载 WhisperKit CoreML 模型并准备集成到 Xcode 项目

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
MODELS_DIR="./WhisperModels"
# 使用 HuggingFace 镜像站（国内加速）
BASE_URL="https://hf-mirror.com/argmaxinc/whisperkit-coreml/resolve/main"
# 原始地址（备用）: https://huggingface.co/argmaxinc/whisperkit-coreml/resolve/main

# 可用模型列表
AVAILABLE_MODELS=("tiny" "base" "small" "medium" "large-v3")

echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   WhisperKit 模型下载工具（镜像站加速）${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo

# 显示可用模型
echo
echo -e "${BLUE}可用模型:${NC}"
echo "  1) tiny     (~75MB)  - 最快，精度较低"
echo "  2) base     (~145MB) - 快速，中等精度"
echo "  3) small    (~245MB) - 推荐，平衡性能和精度"
echo "  4) medium   (~769MB) - 高精度"
echo "  5) large-v3 (~1.5GB) - 最高精度"
echo

# 读取用户选择
read -p "请选择要下载的模型 (1-5): " choice

case $choice in
    1) MODEL="tiny";;
    2) MODEL="base";;
    3) MODEL="small";;
    4) MODEL="medium";;
    5) MODEL="large-v3";;
    *)
        echo -e "${RED}❌ 无效选择${NC}"
        exit 1
        ;;
esac

MODEL_FOLDER="openai_whisper-${MODEL}"
MODEL_PATH="$MODELS_DIR/$MODEL_FOLDER"

echo
echo -e "${BLUE}将下载模型: ${MODEL}${NC}"
echo -e "${BLUE}目标路径: ${MODEL_PATH}${NC}"
echo

# 创建模型目录
mkdir -p "$MODEL_PATH/AudioEncoder.mlmodelc/weights"
mkdir -p "$MODEL_PATH/TextDecoder.mlmodelc/weights"
mkdir -p "$MODEL_PATH/MelSpectrogram.mlmodelc/weights"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📦 下载模型: ${MODEL}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

# 定义要下载的文件
FILES=(
    "config.json"
    "generation_config.json"
    "AudioEncoder.mlcomputeplan.json"
    "TextDecoder.mlcomputeplan.json"
    "MelSpectrogram.mlcomputeplan.json"
)

# 下载配置文件
for file in "${FILES[@]}"; do
    echo -e "${YELLOW}下载: $file${NC}"
    curl -L -o "$MODEL_PATH/$file" "$BASE_URL/$MODEL_FOLDER/$file" --progress-bar || {
        echo -e "${RED}❌ 下载失败: $file${NC}"
    }
done

# 下载 mlmodelc 文件
for component in "AudioEncoder" "TextDecoder" "MelSpectrogram"; do
    echo
    echo -e "${YELLOW}📥 下载 ${component} 组件...${NC}"
    
    # 下载 metadata.json
    curl -L -o "$MODEL_PATH/${component}.mlmodelc/metadata.json" \
        "$BASE_URL/$MODEL_FOLDER/${component}.mlmodelc/metadata.json" \
        --progress-bar 2>/dev/null || true
    
    # 下载 model.mil
    curl -L -o "$MODEL_PATH/${component}.mlmodelc/model.mil" \
        "$BASE_URL/$MODEL_FOLDER/${component}.mlmodelc/model.mil" \
        --progress-bar || {
        echo -e "${RED}❌ 下载失败: ${component}.mlmodelc/model.mil${NC}"
    }
    
    # 下载 coremldata.bin
    curl -L -o "$MODEL_PATH/${component}.mlmodelc/coremldata.bin" \
        "$BASE_URL/$MODEL_FOLDER/${component}.mlmodelc/coremldata.bin" \
        --progress-bar 2>/dev/null || true
    
    # 下载权重文件（最大的文件）
    echo -e "${YELLOW}📥 下载 ${component} 权重文件（可能较大）...${NC}"
    curl -L -o "$MODEL_PATH/${component}.mlmodelc/weights/weight.bin" \
        "$BASE_URL/$MODEL_FOLDER/${component}.mlmodelc/weights/weight.bin" \
        --progress-bar || {
        echo -e "${RED}❌ 下载失败: ${component} 权重${NC}"
        echo -e "${YELLOW}提示：如果下载失败，可能需要使用代理或稍后重试${NC}"
    }
done

echo
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ 下载完成!${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo

# 验证下载结果
if [ -d "$MODEL_PATH" ]; then
    size=$(du -sh "$MODEL_PATH" | cut -f1)
    echo -e "${BLUE}已下载的模型:${NC}"
    echo -e "  ${GREEN}✅${NC} $MODEL_PATH ($size)"
    echo
    
    # 检查权重文件
    echo -e "${BLUE}模型组件检查:${NC}"
    for component in "AudioEncoder" "TextDecoder" "MelSpectrogram"; do
        weight_file="$MODEL_PATH/${component}.mlmodelc/weights/weight.bin"
        if [ -f "$weight_file" ]; then
            weight_size=$(stat -f%z "$weight_file" 2>/dev/null || stat -c%s "$weight_file" 2>/dev/null)
            weight_size_mb=$((weight_size / 1024 / 1024))
            if [ "$weight_size" -lt 1000 ]; then
                echo -e "  ${RED}❌${NC} ${component}: 权重文件未完整下载 ($weight_size bytes)"
            else
                echo -e "  ${GREEN}✅${NC} ${component}: ${weight_size_mb}MB"
            fi
        else
            echo -e "  ${RED}❌${NC} ${component}: 权重文件不存在"
        fi
    done
fi

echo
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ 下载完成!${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo

# 验证下载结果
if [ -d "$MODEL_PATH" ]; then
    size=$(du -sh "$MODEL_PATH" | cut -f1)
    echo -e "${BLUE}已下载的模型:${NC}"
    echo -e "  ${GREEN}✅${NC} $MODEL_PATH ($size)"
    echo
    
    # 检查权重文件
    echo -e "${BLUE}模型组件检查:${NC}"
    for component in "AudioEncoder" "TextDecoder" "MelSpectrogram"; do
        weight_file="$MODEL_PATH/${component}.mlmodelc/weights/weight.bin"
        if [ -f "$weight_file" ]; then
            weight_size=$(stat -f%z "$weight_file" 2>/dev/null || stat -c%s "$weight_file" 2>/dev/null)
            weight_size_mb=$((weight_size / 1024 / 1024))
            if [ "$weight_size" -lt 1000 ]; then
                echo -e "  ${RED}❌${NC} ${component}: 权重文件未完整下载 ($weight_size bytes)"
            else
                echo -e "  ${GREEN}✅${NC} ${component}: ${weight_size_mb}MB"
            fi
        else
            echo -e "  ${RED}❌${NC} ${component}: 权重文件不存在"
        fi
    done
fi

echo
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}📝 下一步操作:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
echo "1. 打开 VoiceTalkie.xcodeproj"
echo "2. 在项目导航器中创建 Models 组"
echo "3. 将 $MODEL_PATH 文件夹拖入 Xcode"
echo "4. 确保勾选:"
echo "   ✅ Copy items if needed"
echo "   ✅ Create folder references (重要!)"
echo "   ✅ Target: VoiceTalkie"
echo "5. 编译并运行应用"
echo
