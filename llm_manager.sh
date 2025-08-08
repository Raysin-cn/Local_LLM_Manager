#!/bin/bash

# =============================================
# 本地大语言模型综合管理脚本
# =============================================

# 加载环境变量
if [ -f .env ]; then
    source .env
else
    echo -e "\033[0;31m❌ 错误: .env 文件不存在\033[0m"
    exit 1
fi

# 配置参数
SCRIPTS_DIR="$(dirname "$0")/scripts"  # 脚本目录
MODEL_ROOT="${MODEL_ROOT:-$(pwd)}"     # 模型根目录

# 设置Python解释器路径
# if [ -z "$PYTHON_PATH" ]; then
#     PYTHON_PATH=$(which python3)
#     if [ -z "$PYTHON_PATH" ]; then
#         PYTHON_PATH=$(which python)
#     fi
#     if [ -z "$PYTHON_PATH" ]; then
#         echo -e "\033[0;31m❌ 错误: 未找到Python解释器\033[0m"
#         exit 1
#     fi
# fi
PYTHON_PATH="/home/models/.venv/bin/python"

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
    
    if [ ! -d "$SCRIPTS_DIR" ]; then
        echo -e "${RED}❌ 错误: 脚本目录不存在: $SCRIPTS_DIR${NC}"
        return 1
    fi
    
    return 0
}

# 函数：显示菜单
show_menu() {
    clear
    echo "============================================="
    echo "🤖 本地大语言模型综合管理系统"
    echo "============================================="
    echo "1. 模型下载管理"
    echo "2. 模型服务管理"
    echo "3. 系统状态检查"
    echo "0. 退出"
    echo "============================================="
    echo -n "请选择操作 [0-3]: "
}

# 函数：检查系统状态
check_system_status() {
    echo "============================================="
    echo "📊 系统状态检查"
    echo "============================================="
    
    # 检查Python环境
    echo "🔍 Python环境:"
    if [ -x "$PYTHON_PATH" ]; then
        echo -e "  ├─ ${GREEN}Python解释器: $PYTHON_PATH${NC}"
        python_version=$("$PYTHON_PATH" --version 2>&1)
        echo "  └─ 版本: $python_version"
    else
        echo -e "  └─ ${RED}Python解释器不存在或不可执行${NC}"
    fi
    
    # 检查模型目录
    echo ""
    echo "📂 模型目录:"
    if [ -d "$MODEL_ROOT" ]; then
        echo -e "  ├─ ${GREEN}模型根目录: $MODEL_ROOT${NC}"
        model_count=$(find "$MODEL_ROOT" -maxdepth 2 -name "config.json" | wc -l)
        echo "  └─ 已安装模型数量: $model_count"
    else
        echo -e "  └─ ${RED}模型根目录不存在${NC}"
    fi
    
    # 检查脚本目录
    echo ""
    echo "📜 脚本状态:"
    if [ -f "$SCRIPTS_DIR/huggingface_cli.sh" ]; then
        echo -e "  ├─ ${GREEN}模型下载脚本: 可用${NC}"
    else
        echo -e "  ├─ ${RED}模型下载脚本: 不可用${NC}"
    fi
    
    if [ -f "$SCRIPTS_DIR/model_server.sh" ]; then
        echo -e "  └─ ${GREEN}服务管理脚本: 可用${NC}"
    else
        echo -e "  └─ ${RED}服务管理脚本: 不可用${NC}"
    fi
    
    # 检查GPU状态
    echo ""
    echo "🎮 GPU状态:"
    if command -v nvidia-smi &> /dev/null; then
        gpu_info=$(nvidia-smi --query-gpu=name,memory.total,memory.free --format=csv,noheader,nounits 2>/dev/null)
        if [ $? -eq 0 ]; then
            # 只取第一行数据，避免多GPU时的重复显示
            gpu_info=$(echo "$gpu_info" | head -n 1)
            gpu_name=$(echo "$gpu_info" | awk -F',' '{print $1}' | xargs)
            gpu_total=$(echo "$gpu_info" | awk -F',' '{print $2}' | xargs)
            gpu_free=$(echo "$gpu_info" | awk -F',' '{print $3}' | xargs)
            echo "  ├─ 型号: $gpu_name"
            echo "  ├─ 总显存: $gpu_total MB"
            echo "  └─ 可用显存: $gpu_free MB"
        else
            echo -e "  └─ ${YELLOW}无法获取GPU信息${NC}"
        fi
    else
        echo -e "  └─ ${YELLOW}未检测到NVIDIA驱动${NC}"
    fi
}

# 主循环
while true; do
    show_menu
    read -r opt
    echo ""
    case $opt in
        1)
            if [ -f "$SCRIPTS_DIR/huggingface_cli.sh" ]; then
                bash "$SCRIPTS_DIR/huggingface_cli.sh"
            else
                echo -e "${RED}❌ 错误: 模型下载脚本不存在${NC}"
            fi
            ;;
        2)
            if [ -f "$SCRIPTS_DIR/model_server.sh" ]; then
                bash "$SCRIPTS_DIR/model_server.sh"
            else
                echo -e "${RED}ESTABLISHED 错误: 服务管理脚本不存在${NC}"
            fi
            ;;
        3)
            check_system_status
            ;;
        0)
            echo "👋 再见！"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ 无效的选项${NC}"
            ;;
    esac
    echo ""
    echo -n "按回车键继续..."
    read -r
done 