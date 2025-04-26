# 本地大语言模型服务系统

本项目提供了本地大语言模型的部署和管理方案，使用 vLLM 作为推理引擎。支持多个模型的管理和切换。

## 项目结构

```
.
├── README.md                 # 项目说明文档
├── requirements.txt          # 项目需求库
├── scripts/                  # 脚本目录
│   ├── model_server.sh       # 模型服务管理脚本
│   └── test_api.sh          # API 测试脚本
└── examples/                 # 示例代码
    ├── test_model.py        # Python API 测试示例
    └── langchain_example.py # LangChain 调用示例
```

## 环境要求

- Python 3.8+
- CUDA 11.8+
- vLLM 0.8.4+
- LangChain 0.1.0+

## 快速开始

1. 安装依赖：
```bash
conda create -n llm python=3.10
pip install -r ./requirements.txt
```

2. 模型管理：
```bash
# 启动管理界面
bash scripts/model_server.sh
```

在管理界面中，您可以：
- 启动模型服务
- 停止模型服务
- 查看服务状态
- 查看服务日志

3. 测试服务：
```bash
# 使用 curl 测试
bash scripts/test_api.sh

# 或使用 Python 测试
python examples/test_model.py

# 或使用 LangChain 测试
python examples/langchain_example.py
```

## 支持的模型

系统会自动检测 `/home/models` 目录下的所有模型。每个模型目录需要包含：
- `config.json`：模型配置文件
- `model.safetensors` 或 `pytorch_model.bin`：模型权重文件
- `tokenizer.json` 或 `tokenizer.model`：分词器文件

## API 使用说明

### 基础配置
- 服务地址：`http://localhost:12345`
- API 端点：`/v1/chat/completions`
- API Key：任意字符串

### 请求示例

```bash
curl -X POST http://localhost:12345/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-api-key" \
  -d '{
    "model": "模型路径",
    "messages": [
      {"role": "system", "content": "你是一个有用的AI助手。"},
      {"role": "user", "content": "你好"}
    ],
    "temperature": 0.7,
    "max_tokens": 100
  }'
```

### LangChain 调用示例

```python
from langchain_openai import ChatOpenAI
from langchain.schema import HumanMessage, SystemMessage

llm = ChatOpenAI(
    model_name="模型路径",
    openai_api_base="http://localhost:12345/v1",
    openai_api_key="test-key",
    temperature=0.7,
    max_tokens=100
)

messages = [
    SystemMessage(content="你是一个有用的AI助手。"),
    HumanMessage(content="你好")
]

response = llm.invoke(messages)
print(response.content)
```

## 参数说明

### 启动参数
- `--model`: 模型路径
- `--port`: 服务端口
- `--dtype`: 模型精度（float16）
- `--tensor-parallel-size`: 张量并行大小

### API 参数
- `model`: 模型路径
- `messages`: 对话历史
- `temperature`: 温度参数（0-1）
- `max_tokens`: 最大生成 token 数

## 注意事项

1. 确保模型文件路径正确
2. 确保有足够的 GPU 内存
3. 首次启动可能需要较长时间加载模型
4. 同一时间只能运行一个模型服务

## 常见问题

1. 模型加载失败
   - 检查模型路径是否正确
   - 检查 GPU 内存是否足够
   - 检查模型文件是否完整

2. API 请求失败
   - 检查服务是否正常运行
   - 检查请求格式是否正确
   - 检查模型路径是否正确

## 许可证

MIT License
