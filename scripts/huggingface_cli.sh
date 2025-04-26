#!/bin/bash

# =============================================
# Hugging Face 模型下载工具
# =============================================

# 加载环境变量
if [ -f "$(dirname "$0")/../.env" ]; then
    source "$(dirname "$0")/../.env"
else
    echo -e "\033[0;31m❌ 错误: .env 文件不存在\033[0m"
    exit 1
fi

# 配置参数
MODEL_ROOT="${MODEL_ROOT:-$(pwd)}"     # 模型根目录

# 设置Python解释器路径
if [ -z "$PYTHON_PATH" ]; then
    PYTHON_PATH=$(which python3)
    if [ -z "$PYTHON_PATH" ]; then
        PYTHON_PATH=$(which python)
    fi
    if [ -z "$PYTHON_PATH" ]; then
        echo -e "\033[0;31m❌ 错误: 未找到Python解释器\033[0m"
        exit 1
    fi
fi

# 设置Hugging Face相关路径
HF_CLI_PATH="$(dirname "$PYTHON_PATH")/huggingface-cli"
HF_ENDPOINT="${HF_ENDPOINT:-https://hf-mirror.com}"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 函数：检查环境
check_env() {
    if [ ! -x "$PYTHON_PATH" ]; then
        echo -e "${RED}❌ 错误: Python解释器不存在或不可执行: $PYTHON_PATH${NC}"
        return 1
    fi
    
    if [ ! -x "$HF_CLI_PATH" ]; then
        echo -e "${RED}❌ 错误: huggingface-cli不存在或不可执行: $HF_CLI_PATH${NC}"
        return 1
    fi
    
    return 0
}

# 检查环境
if ! check_env; then
    exit 1
fi

# 显示菜单
echo "============================================="
echo "🤖 Hugging Face 模型下载工具"
echo "============================================="
echo "1. 下载 ChatGLM3-6B"
echo "2. 下载 Qwen1.5-7B-Chat"
echo "3. 下载 Qwen2.5-VL-7B-Instruct"
echo "4. 自定义下载"
echo "0. 返回上一级"
echo "============================================="
echo -n "请选择要下载的模型 [0-4]: "

read -r choice
echo ""

case $choice in
    1)
        echo -e "${YELLOW}⏳ 正在下载 ChatGLM3-6B...${NC}"
        model_id="THUDM/chatglm3-6b"
        model_name="chatglm3-6b"
        model_dir="$MODEL_ROOT/$model_name"
        mkdir -p "$model_dir"
        "$HF_CLI_PATH" download "$model_id" --local-dir "$model_dir"
        ;;
    2)
        echo -e "${YELLOW}⏳ 正在下载 Qwen1.5-7B-Chat...${NC}"
        model_id="Qwen/Qwen1.5-7B-Chat"
        model_name="Qwen1.5-7B-Chat"
        model_dir="$MODEL_ROOT/$model_name"
        mkdir -p "$model_dir"
        "$HF_CLI_PATH" download "$model_id" --local-dir "$model_dir"
        ;;
    3)
        echo -e "${YELLOW}⏳ 正在下载 Qwen2.5-VL-7B-Instruct...${NC}"
        model_id="Qwen/Qwen2.5-VL-7B-Instruct"
        model_name="Qwen2.5-VL-7B-Instruct"
        model_dir="$MODEL_ROOT/$model_name"
        mkdir -p "$model_dir"
        "$HF_CLI_PATH" download "$model_id" --local-dir "$model_dir"
        ;;
    4)
        echo "请输入模型ID（例如：THUDM/chatglm3-6b）："
        read -r model_id
        
        # 从模型ID中提取模型名
        model_name=$(echo "$model_id" | cut -d'/' -f2)
        if [ -z "$model_name" ]; then
            echo -e "${RED}❌ 无效的模型ID格式，请使用 组织名/模型名 的格式${NC}"
            exit 1
        fi
        
        # 设置保存路径
        model_dir="$MODEL_ROOT/$model_name"
        echo "模型将保存到: $model_dir"
        
        echo -e "${YELLOW}⏳ 正在下载 $model_id...${NC}"
        mkdir -p "$model_dir"
        "$HF_CLI_PATH" download "$model_id" --local-dir "$model_dir" --local-dir-use-symlinks False
        ;;
    0)
        echo "👋 返回上一级"
        exit 0
        ;;
    *)
        echo -e "${RED}❌ 无效的选项${NC}"
        exit 1
        ;;
esac

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 下载完成！${NC}"
    echo "模型已保存到: $model_dir"
else
    echo -e "${RED}❌ 下载失败，请检查错误信息${NC}"
fi