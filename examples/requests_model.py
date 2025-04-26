import requests
import json

# 测试配置
API_URL = "http://localhost:12345/v1/chat/completions"
API_KEY = "test-key"  # 可以是任意字符串

# 测试请求数据
test_data = {
    "model": "/home/models/Qwen/Qwen1.5-7B-Chat",  # 使用完整的模型路径
    "messages": [
        {"role": "system", "content": "你是一个有用的AI助手。"},
        {"role": "user", "content": "你好，请介绍一下你自己。"}
    ],
    "temperature": 0.7,
    "max_tokens": 100
}

# 发送请求
headers = {
    "Content-Type": "application/json",
    "Authorization": f"Bearer {API_KEY}"
}

try:
    print("正在发送测试请求...")
    response = requests.post(API_URL, headers=headers, json=test_data)
    
    # 检查响应
    if response.status_code == 200:
        result = response.json()
        print("\n✅ 模型服务响应成功！")
        print("\n模型回复：")
        print(result["choices"][0]["message"]["content"])
    else:
        print(f"\n❌ 请求失败，状态码：{response.status_code}")
        print("错误信息：")
        print(response.text)

except Exception as e:
    print(f"\n❌ 发生错误：{str(e)}") 