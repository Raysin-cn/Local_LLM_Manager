#!/bin/bash

# =============================================
# 本地大语言模型服务管理脚本
# =============================================

# 加载环境变量
if [ -f "$(dirname "$0")/../.env" ]; then
    source "$(dirname "$0")/../.env"
else
    echo -e "\033[0;31m❌ 错误: .env 文件不存在\033[0m"
    exit 1
fi

# 设置vLLM引擎版本（可解决某些模型的FlashAttention兼容性问题）
# export VLLM_USE_V1=0

# 配置参数
MODEL_ROOT="${MODEL_ROOT:-$(pwd)}"     # 模型根目录
PORT="${PORT:-12345}"                  # 服务端口
DTYPE="${DTYPE:-float16}"             # 模型精度
LOG_FILE="${LOG_FILE:-$MODEL_ROOT/llm_server.log}" # 日志文件
SELECTED_MODEL=""                      # 存储选择的模型路径

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
PYTHON_PATH="/home/models/venv/llm/bin/python"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 函数：显示菜单
show_menu() {
    clear
    echo "============================================="
    echo "🤖 模型服务管理"
    echo "============================================="
    echo "1. 启动模型服务"
    echo "2. 停止模型服务"
    echo "3. 查看服务状态"
    echo "4. 查看服务日志"
    echo "0. 返回上一级"
    echo "============================================="
    echo -n "请选择操作 [0-4]: "
}

# 函数：列出可用模型
list_models() {
    echo "============================================="
    echo "📚 可用模型列表："
    echo "============================================="
    
    echo "当前工作目录: $(pwd)"
    echo "模型根目录: $MODEL_ROOT"
    
    # 直接使用find命令查找模型
    local models=()
    local i=1
    
    while IFS= read -r model_path; do
        model_dir=$(dirname "$model_path")
        model_name=$(basename "$model_dir")
        models[$i]=$model_dir
        echo "$i) $model_name (路径: $model_dir)"
        ((i++))
    done < <(find "$MODEL_ROOT" -maxdepth 2 -name "config.json" 2>/dev/null)
    
    if [ $i -eq 1 ]; then
        echo -e "${YELLOW}⚠️ 未找到任何模型${NC}"
        return 1
    fi
    
    echo "============================================="
    echo -n "请选择要启动的模型 [1-$((i-1))]: "
    
    read -r choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -lt "$i" ]; then
        SELECTED_MODEL="${models[$choice]}"
    else
        SELECTED_MODEL=""
    fi
}

# 函数：检查Python解释器
check_python() {
    if [ ! -x "$PYTHON_PATH" ]; then
        echo -e "${RED}❌ 错误: Python解释器不存在或不可执行: $PYTHON_PATH${NC}"
        return 1
    fi
    
    # 检查Python版本和必要的包
    if ! "$PYTHON_PATH" -c "import vllm" 2>/dev/null; then
        echo -e "${RED}❌ 错误: vllm包未安装，请先安装必要的依赖${NC}"
        return 1
    fi
    
    return 0
}

# 获取空闲显存最多的GPU索引
get_best_cuda_idx() {
    local best_idx=0
    local max_free=0
    local count=0
    # 获取每张卡的空闲显存（单位MiB）
    while read -r idx free; do
        if [ "$free" -gt "$max_free" ]; then
            max_free=$free
            best_idx=$idx
        fi
        ((count++))
    done < <(nvidia-smi --query-gpu=index,memory.free --format=csv,noheader,nounits)
    echo $best_idx
}

# 函数：启动服务
start_server() {
    if lsof -i :$PORT > /dev/null; then
        echo -e "${RED}❌ 错误: 端口 $PORT 已被占用${NC}"
        return 1
    fi
    
    # 检查Python环境
    if ! check_python; then
        return 1
    fi
    
    # 获取选择的模型路径
    list_models
    
    # 检查模型路径是否为空或无效
    if [ -z "$SELECTED_MODEL" ] || [ ! -d "$SELECTED_MODEL" ]; then
        echo -e "${RED}❌ 错误: 未选择有效的模型${NC}"
        return 1
    fi
    
    # 获取模型名称
    local MODEL_NAME=$(basename "$SELECTED_MODEL")

    # 选择空闲显存最多的GPU
    CUDA_IDX=$(get_best_cuda_idx)
    export CUDA_VISIBLE_DEVICES=$CUDA_IDX
    echo "🚀 选择的GPU: $CUDA_IDX (空闲显存最大)"

    # 启动服务前，删除旧日志文件
    if [ -f "/home/models/llm_service.log" ]; then
        rm -f /home/models/llm_service.log
    fi


    echo -e "${YELLOW}⏳ 正在启动服务...${NC}"
    echo "🤖 使用Python: $PYTHON_PATH"
    echo "📂 模型路径: $SELECTED_MODEL"
    echo "🔌 服务端口: $PORT"
    echo "🎯 模型精度: $DTYPE"
    
    # 启动服务  # tool-call-parser 注意必须使用hermes，兼容Openai模式的tool_calls
    "$PYTHON_PATH" -m vllm.entrypoints.openai.api_server \
        --model "$SELECTED_MODEL" \
        --served-model-name "$MODEL_NAME" \
        --port "$PORT" \
        --dtype "$DTYPE" \
        --tensor-parallel-size 1 \
        --enable-auto-tool-choice \
        --tool-call-parser hermes \
        > "$LOG_FILE" 2>&1 &
    sleep 10
    if lsof -i :$PORT > /dev/null; then
        echo -e "${GREEN}✅ 服务启动成功！${NC}"
        echo "🌐 服务地址: http://localhost:$PORT"
        echo "🎯 日志文件: $LOG_FILE${NC}"
        echo "🔑 API Key: 任意字符串"
    else
        echo -e "${YELLOW}⚠️ 服务启动失败或启动时间过长，请检查日志文件: $LOG_FILE${NC}"
    fi
}

# 函数：停止服务
stop_server() {
    local PID=$(lsof -t -i:$PORT)
    
    if [ -z "$PID" ]; then
        echo -e "${YELLOW}⚠️ 未发现运行中的服务${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}⏳ 正在停止服务 (PID: $PID)...${NC}"
    
    kill $PID
    sleep 2
    
    if kill -0 $PID 2>/dev/null; then
        echo -e "${YELLOW}⚠️ 服务未响应，强制终止...${NC}"
        kill -9 $PID
        sleep 1
    fi
    
    if ! lsof -i :$PORT > /dev/null; then
        echo -e "${GREEN}✅ 服务已成功停止${NC}"
    else
        echo -e "${RED}❌ 服务停止失败${NC}"
    fi
}

# 函数：查看服务状态
check_status() {
    echo "============================================="
    echo "📊 服务状态检查"
    echo "============================================="
    
    local PID=$(lsof -t -i:$PORT)
    if [ -n "$PID" ]; then
        # 从日志文件中提取模型信息
        local model_path
        if [ -f "$LOG_FILE" ]; then
            model_path=$(grep -m 1 "model='" "$LOG_FILE" | sed "s/.*model='\([^']*\)'.*/\1/")
            if [ -n "$model_path" ]; then
                SELECTED_MODEL="$model_path"
            fi
        fi
        
        # 获取模型名称
        local model_name=$(basename "$SELECTED_MODEL")
        if [ -z "$model_name" ]; then
            model_name="未知模型"
        fi
        
        # 获取内存使用情况
        local mem_usage=$(ps -o rss= -p $PID | awk '{print $1/1024 "MB"}')
        
        # 获取运行时长
        local uptime=$(ps -o etime= -p $PID)
        
        # 获取GPU使用情况
        local gpu_info=$(nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv,noheader,nounits 2>/dev/null)
        if [ $? -eq 0 ]; then
            # 只取第一行数据，避免多GPU时的重复显示
            gpu_info=$(echo "$gpu_info" | head -n 1)
            gpu_usage=$(echo "$gpu_info" | awk -F',' '{print $1"%"}')
            gpu_mem=$(echo "$gpu_info" | awk -F',' '{print $2"MB"}')
        else
            gpu_usage="N/A"
            gpu_mem="N/A"
        fi
        
        # 获取主机名和IP地址
        local hostname=$(hostname)
        local ip_address=$(hostname -I | awk '{print $1}')
        
        echo -e "${GREEN}✅ 服务运行中${NC}"
        echo "🤖 模型信息:"
        echo "  ├─ 名称: $model_name"
        echo "  └─ 路径: $SELECTED_MODEL"
        echo ""
        echo "🌐 服务信息:"
        echo "  ├─ 主机名: $hostname"
        echo "  ├─ IP地址: $ip_address"
        echo "  ├─ 服务端口: $PORT"
        echo "  └─ API地址: http://$ip_address:$PORT"
        echo ""
        echo "📊 资源使用:"
        echo "  ├─ 进程ID: $PID"
        echo "  ├─ 内存使用: $mem_usage"
        echo "  ├─ GPU使用: $gpu_usage"
        echo "  └─ GPU显存: $gpu_mem"
        echo ""
        echo "🎯 日志文件: $LOG_FILE${NC}"
        echo "🎯 查看最新20行日志: tail -n 20 $LOG_FILE"
        echo "⏱️ 运行时长: $uptime"
        
        # 检查API是否可访问
        echo ""
        echo "🔍 API状态:"
        if curl -s "http://localhost:$PORT/health" > /dev/null; then
            echo -e "  └─ ${GREEN}服务正常${NC}"
            
            # 获取API版本信息
            local api_version=$(curl -s "http://localhost:$PORT/version" | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
            if [ -n "$api_version" ]; then
                echo "    └─ API版本: $api_version"
            fi
        else
            echo -e "  └─ ${YELLOW}服务不可访问${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ 服务未运行${NC}"
        # 尝试从日志文件中获取上次运行的模型
        if [ -f "$LOG_FILE" ]; then
            local last_model=$(grep -m 1 "model='" "$LOG_FILE" | sed "s/.*model='\([^']*\)'.*/\1/")
            if [ -n "$last_model" ]; then
                echo ""
                echo "📜 上次运行信息:"
                echo "  ├─ 模型名称: $(basename "$last_model")"
                echo "  └─ 模型路径: $last_model"
                SELECTED_MODEL="$last_model"
            fi
        fi
    fi
}

# 函数：查看日志
view_logs() {
    if [ -f "$LOG_FILE" ]; then
        echo "============================================="
        echo "📝 最新日志内容："
        echo "============================================="
        echo "日志文件: $LOG_FILE"
        echo "============================================="
        tail -n 20 "$LOG_FILE"
    else
        echo -e "${YELLOW}⚠️ 日志文件不存在: $LOG_FILE${NC}"
        echo -e "${YELLOW}请先启动服务以创建日志文件${NC}"
    fi
}

# 主循环
while true; do
    show_menu
    read -r opt
    echo ""
    case $opt in
        1) start_server ;;
        2) stop_server ;;
        3) check_status ;;
        4) view_logs ;;
        0) echo "👋 再见！"; exit 0 ;;
        *) echo -e "${RED}❌ 无效的选项${NC}" ;;
    esac
    echo ""
    echo -n "按回车键继续..."
    read -r
done 