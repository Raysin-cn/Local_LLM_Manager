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
# 设置vLLM引擎版本（解决某些模型的FlashAttention兼容性问题）
export VLLM_USE_V1=0

# 配置参数
MODEL_ROOT="${MODEL_ROOT:-$(pwd)}"     # 模型根目录
PORT="${PORT:-12345}"                  # 服务端口
DTYPE="${DTYPE:-float16}"              # 模型精度
LOG_FILE="${LOG_FILE:-$MODEL_ROOT/llm_server.log}" # 日志文件
SELECTED_MODEL=""                      # 存储选择的模型路径
MANUAL_CUDA_IDX=""                     # 手动指定的CUDA索引
CUSTOM_GPU_MEMORY_UTIL=""              # 自定义GPU显存使用率

# 转换为绝对路径
MODEL_ROOT="$(cd "$(dirname "$MODEL_ROOT")" && pwd)/$(basename "$MODEL_ROOT")"
LOG_FILE="$(cd "$(dirname "$LOG_FILE")" && pwd)/$(basename "$LOG_FILE")"

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
    echo "5. GPU配置管理"
    echo "0. 返回上一级"
    echo "============================================="
    echo -n "请选择操作 [0-5]: "
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

# 函数：显示GPU信息
show_gpu_info() {
    echo "============================================="
    echo "🎮 当前GPU状态："
    echo "============================================="
    
    if command -v nvidia-smi &> /dev/null; then
        # 显示GPU列表和状态
        echo "GPU索引 | 型号 | 总显存(MB) | 已用显存(MB) | 空闲显存(MB) | 使用率(%)"
        echo "---------|------|------------|-------------|-------------|----------"
        while read -r line; do
            echo "$line"
        done < <(nvidia-smi --query-gpu=index,name,memory.total,memory.used,memory.free,utilization.gpu --format=csv,noheader,nounits | awk -F', ' '{printf "   %s    | %s | %s | %s | %s | %s\n", $1, $2, $3, $4, $5, $6}')
    else
        echo -e "${YELLOW}⚠️ 未检测到NVIDIA驱动或nvidia-smi命令${NC}"
        return 1
    fi
}

# 函数：GPU配置管理
gpu_config() {
    while true; do
        clear
        echo "============================================="
        echo "🎮 GPU配置管理"
        echo "============================================="
        
        # 显示当前配置
        if [ -n "$MANUAL_CUDA_IDX" ]; then
            echo -e "当前GPU配置: ${GREEN}手动指定 GPU $MANUAL_CUDA_IDX${NC}"
        else
            echo -e "当前GPU配置: ${YELLOW}自动选择 (空闲显存最大)${NC}"
        fi
        
        if [ -n "$CUSTOM_GPU_MEMORY_UTIL" ]; then
            echo -e "显存使用率: ${GREEN}自定义 ${CUSTOM_GPU_MEMORY_UTIL}${NC}"
        else
            echo -e "显存使用率: ${YELLOW}自动 (根据模型大小)${NC}"
        fi
        
        echo ""
        echo "1. 查看GPU状态"
        echo "2. 设置手动指定GPU"
        echo "3. 切换为自动选择GPU"
        echo "4. 设置自定义显存使用率"
        echo "5. 切换为自动显存管理"
        echo "0. 返回上一级"
        echo "============================================="
        echo -n "请选择操作 [0-5]: "
        
        read -r gpu_opt
        echo ""
        
        case $gpu_opt in
            1)
                show_gpu_info
                ;;
            2)
                show_gpu_info
                echo ""
                echo -n "请输入要使用的GPU索引: "
                read -r gpu_idx
                
                # 验证输入的GPU索引
                if [[ "$gpu_idx" =~ ^[0-9]+$ ]]; then
                    # 检查GPU索引是否存在
                    local gpu_count=$(nvidia-smi --query-gpu=index --format=csv,noheader | wc -l)
                    if [ "$gpu_idx" -ge 0 ] && [ "$gpu_idx" -lt "$gpu_count" ]; then
                        MANUAL_CUDA_IDX="$gpu_idx"
                        echo -e "${GREEN}✅ 已设置为使用GPU $gpu_idx${NC}"
                    else
                        echo -e "${RED}❌ 错误: GPU索引超出范围 (0-$((gpu_count-1)))${NC}"
                    fi
                else
                    echo -e "${RED}❌ 错误: 请输入有效的数字${NC}"
                fi
                ;;
            3)
                MANUAL_CUDA_IDX=""
                echo -e "${GREEN}✅ 已切换为自动选择GPU (空闲显存最大)${NC}"
                ;;
            4)
                echo -n "请输入GPU显存使用率 (0.1-1.0, 例如 0.6 表示60%): "
                read -r memory_util
                
                # 验证输入的显存使用率
                if [[ "$memory_util" =~ ^0\.[1-9][0-9]*$|^1\.0*$ ]]; then
                    CUSTOM_GPU_MEMORY_UTIL="$memory_util"
                    echo -e "${GREEN}✅ 已设置显存使用率为 $memory_util${NC}"
                else
                    echo -e "${RED}❌ 错误: 请输入有效的显存使用率 (0.1-1.0, 例如: 0.6)${NC}"
                fi
                ;;
            5)
                CUSTOM_GPU_MEMORY_UTIL=""
                echo -e "${GREEN}✅ 已切换为自动显存管理 (根据模型大小自动调整)${NC}"
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}❌ 无效的选项${NC}"
                ;;
        esac
        
        if [ "$gpu_opt" != "0" ]; then
            echo ""
            echo -n "按回车键继续..."
            read -r
        fi
    done
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
    
    # 提取模型友好名称
    local MODEL_NAME=$(basename "$SELECTED_MODEL")
    
    # 选择GPU
    if [ -n "$MANUAL_CUDA_IDX" ]; then
        CUDA_IDX="$MANUAL_CUDA_IDX"
        echo "🎮 使用手动指定的GPU: $CUDA_IDX"
    else
        CUDA_IDX=$(get_best_cuda_idx)
        echo "🚀 自动选择空闲显存最大的GPU: $CUDA_IDX"
    fi
    
    export CUDA_VISIBLE_DEVICES=$CUDA_IDX

    # 启动服务前，删除旧日志文件
    if [ -f "/home/models/llm_service.log" ]; then
        rm -f /home/models/llm_service.log
    fi

    
    echo -e "${YELLOW}⏳ 正在启动服务...${NC}"
    echo "🤖 使用Python: $PYTHON_PATH"
    echo "📂 模型名称: $MODEL_NAME"
    echo "📁 模型路径: $SELECTED_MODEL"
    echo "🔌 服务端口: $PORT"
    echo "🎯 模型精度: $DTYPE"
    
    # 启动服务  # tool-call-parser 注意必须使用hermes，兼容Openai模式的tool_calls
    # 为基础模型添加简单的chat template
    if [[ "$MODEL_NAME" == *"pythia"* ]]; then
        CHAT_TEMPLATE="{% for message in messages %}{{ message['content'] }}{% if not loop.last %}\n{% endif %}{% endfor %}"
        EXTRA_ARGS="--chat-template \"$CHAT_TEMPLATE\""
    else
        EXTRA_ARGS=""
    fi
    
    # 设置显存参数
    local GPU_MEMORY_UTIL
    local MAX_MODEL_LEN="4096"   # 默认最大序列长度
    
    # 优先使用自定义显存使用率，否则根据模型大小自动调整
    if [ -n "$CUSTOM_GPU_MEMORY_UTIL" ]; then
        GPU_MEMORY_UTIL="$CUSTOM_GPU_MEMORY_UTIL"
        echo "🔧 显存配置: 使用自定义显存使用率 ${GPU_MEMORY_UTIL} (${CUSTOM_GPU_MEMORY_UTIL})"
    else
        # 根据模型名称调整参数
        if [[ "$MODEL_NAME" == *"1.7B"* || "$MODEL_NAME" == *"1.8B"* ]]; then
            GPU_MEMORY_UTIL="0.4"  # 小模型使用40%显存
            MAX_MODEL_LEN="8192"
        elif [[ "$MODEL_NAME" == *"2.8B"* || "$MODEL_NAME" == *"3B"* ]]; then
            GPU_MEMORY_UTIL="0.5"  # 中等模型使用50%显存
            MAX_MODEL_LEN="6144"
        elif [[ "$MODEL_NAME" == *"7B"* || "$MODEL_NAME" == *"8B"* ]]; then
            GPU_MEMORY_UTIL="0.7"  # 大模型使用70%显存
            MAX_MODEL_LEN="4096"
        else
            GPU_MEMORY_UTIL="0.6"  # 未知模型使用60%显存
            MAX_MODEL_LEN="4096"
        fi
        echo "🔧 显存配置: 根据模型大小自动设置 ${GPU_MEMORY_UTIL} (${MODEL_NAME})"
    fi
    
    echo "📏 最大序列长度: $MAX_MODEL_LEN"
    
    eval "$PYTHON_PATH -m vllm.entrypoints.openai.api_server \
        --model \"$SELECTED_MODEL\" \
        --served-model-name \"$MODEL_NAME\" \
        --port \"$PORT\" \
        --dtype \"$DTYPE\" \
        --tensor-parallel-size 1 \
        --gpu-memory-utilization $GPU_MEMORY_UTIL \
        --max-model-len $MAX_MODEL_LEN \
        --block-size 16 \
        --enable-auto-tool-choice \
        --tool-call-parser hermes \
        $EXTRA_ARGS \
        > \"$LOG_FILE\" 2>&1 &"
    sleep 10
    if lsof -i :$PORT > /dev/null; then
        echo -e "${GREEN}✅ 模型服务启动成功！${NC}"
        echo "🤖 模型名称: $MODEL_NAME"
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
        echo "  ├─ 服务名称: $model_name"
        echo "  └─ 模型路径: $SELECTED_MODEL"
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
        5) gpu_config ;;
        0) echo "👋 再见！"; exit 0 ;;
        *) echo -e "${RED}❌ 无效的选项${NC}" ;;
    esac
    echo ""
    echo -n "按回车键继续..."
    read -r
done 