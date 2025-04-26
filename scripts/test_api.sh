#!/bin/bash

# 测试配置
API_URL="http://localhost:12345/v1/chat/completions"
API_KEY="test-key"

# 发送请求
curl -X POST $API_URL \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{
    "model": "/home/models/Qwen/Qwen1.5-7B-Chat",
    "messages": [
      {"role": "system", "content": "你是一个有用的AI助手。"},
      {"role": "user", "content": "你是什么大模型"}
    ],
    "temperature": 0.7,
    "max_tokens": 100
  }' 