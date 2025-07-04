# 本地大语言模型管理系统

一个用于管理本地大语言模型的综合工具，支持模型下载、服务部署和状态监控。

## 功能特点

- 🚀 模型下载：支持从 Hugging Face 下载各种大语言模型
- 🔌 服务部署：一键启动/停止模型服务
- 📊 状态监控：实时查看服务状态和资源使用情况
- 🛠️ 配置灵活：通过环境变量轻松配置各项参数
- 🎨 交互友好：彩色终端界面，操作简单直观

## 系统要求

- Linux 操作系统
- Python 3.7+
- NVIDIA GPU（推荐）
- 足够的磁盘空间（根据模型大小而定）

## 快速开始

1. 克隆项目：
```bash
git clone <repository-url>
cd <project-directory>
```

2. 配置环境：
```bash
# 安装相应的库(若存在已安装如下库的python，则可直接在.env中配置解释器路径)
pip install vllm huggingface-hub

# 复制示例配置文件
cp .env.template .env

# 编辑配置文件
vim .env
```

3. 运行管理工具：
```bash
./llm_manager.sh
```

## 配置文件说明

`.env` 文件包含以下主要配置项：

```ini
# Python环境配置
PYTHON_PATH=  # 如果为空，将自动检测系统Python解释器

# 模型配置
MODEL_ROOT=/home/models  # 模型存储根目录
PORT=12345              # 服务端口
DTYPE=float16          # 模型精度

# 日志配置
LOG_FILE=/home/models/llm_service.log  # 日志文件路径

# 服务配置
TENSOR_PARALLEL_SIZE=1
MAX_MODEL_LEN=4096
MAX_BATCH_SIZE=32
MAX_NUM_BATCHED_TOKENS=4096
```

## 使用说明

### 主菜单功能

1. 模型下载管理
   - 支持预置模型快速下载
   - 支持自定义模型下载
   - 自动处理模型依赖

2. 模型服务管理
   - 启动/停止模型服务
   - 查看服务状态
   - 查看服务日志

3. 系统状态检查
   - Python 环境检查
   - 模型目录状态
   - GPU 资源监控

### 常用命令

```bash
# 启动管理工具
./llm_manager.sh

# 直接启动模型服务
./scripts/model_server.sh

# 直接下载模型
./scripts/huggingface_cli.sh
```

## 目录结构

### 项目目录结构
```
.
├── .env                    # 环境配置文件
├── llm_manager.sh          # 主管理脚本
├── scripts/                # 功能脚本目录
│   ├── huggingface_cli.sh  # 模型下载脚本
│   └── model_server.sh     # 服务管理脚本
└── README.md               # 项目说明文档
```

### 模型目录结构
```
MODEL_ROOT/                 # 模型根目录（由 MODEL_ROOT 环境变量指定）
├── chatglm3-6b/           # ChatGLM3-6B 模型目录
│   ├── config.json        # 模型配置文件
│   ├── model.safetensors  # 模型权重文件
│   └── tokenizer.json     # 分词器文件
├── Qwen1.5-7B-Chat/       # Qwen1.5-7B-Chat 模型目录
│   ├── config.json
│   ├── model.safetensors
│   └── tokenizer.json
└── Qwen2.5-VL-7B-Instruct/ # Qwen2.5-VL-7B-Instruct 模型目录
    ├── config.json
    ├── model.safetensors
    └── tokenizer.json
```

## 注意事项

1. 首次使用前请确保：
   - 已安装必要的 Python 包
   - 有足够的磁盘空间
   - GPU 驱动正确安装

2. 服务启动可能需要较长时间，请耐心等待

3. 如果遇到问题：
   - 检查日志文件
   - 确认环境配置
   - 确保端口未被占用

## 常见问题

1. Q: 如何修改服务端口？
   A: 在 `.env` 文件中修改 `PORT` 参数

2. Q: 如何更改模型存储位置？
   A: 在 `.env` 文件中修改 `MODEL_ROOT` 参数

3. Q: 服务启动失败怎么办？
   A: 检查日志文件，确认端口是否被占用，模型是否正确下载

## 贡献指南

欢迎提交 Issue 和 Pull Request 来帮助改进项目。

## 许可证

[MIT License](LICENSE)
