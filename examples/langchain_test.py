from langchain_openai import ChatOpenAI
from langchain.schema import HumanMessage, SystemMessage

# 配置本地模型
llm = ChatOpenAI(
    model_name="/home/models/Qwen2.5-VL-7B-Instruct",  # 模型路径
    openai_api_base="http://192.168.1.100:12345/v1",     # 本地服务地址
    openai_api_key="test-key",                       # 任意字符串
    temperature=0.7,                                 # 温度参数
    max_tokens=100                                   # 最大生成token数
)

# 创建消息
messages = [
    SystemMessage(content="你是一个有用的AI助手。"),
    HumanMessage(content="你好，请介绍一下你自己。")
]

# 调用模型
try:
    print("正在发送请求...")
    response = llm.invoke(messages)
    
    print("\n✅ 模型服务响应成功！")
    print("\n模型回复：")
    print(response.content)
    
except Exception as e:
    print(f"\n❌ 发生错误：{str(e)}") 