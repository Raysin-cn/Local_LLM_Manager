from openai import OpenAI
import json


client = OpenAI(base_url="http://localhost:12345/v1", api_key="dummy")


def get_weather(location: str, unit: str):
    return f"Getting the weather for {location} in {unit}..."
tool_functions = {"get_weather": get_weather}


tools = [{
    "type": "function",
    "function": {
        "name": "get_weather",
        "description": "Get the current weather in a given location",
        "parameters": {
            "type": "object",
            "properties": {
                "location": {"type": "string", "description": "City and state, e.g., 'San Francisco, CA'"},
                "unit": {"type": "string", "enum": ["celsius", "fahrenheit"]}
            },
            "required": ["location", "unit"]
        }
    }
}]

print(f"Current model: {client.models.list().data[0].id}")
response = client.chat.completions.create(
    model=client.models.list().data[0].id,
    messages=[{"role": "user", "content": "What's the weather like in San Francisco?"}],
    tools=tools,
    tool_choice="auto"
)

# 定义颜色
RED = "\033[91m"
GREEN = "\033[92m"
YELLOW = "\033[93m"
BLUE = "\033[94m"
CYAN = "\033[96m"
RESET = "\033[0m"

print(f"{CYAN}Response: {response.choices[0].message}{RESET}")
try:
    tool_call = response.choices[0].message.tool_calls[0].function
    print(f"{YELLOW}Function called: {tool_call.name}{RESET}")
    print(f"{YELLOW}Arguments: {tool_call.arguments}{RESET}")
    print(f"{GREEN}Result: {get_weather(**json.loads(tool_call.arguments))}{RESET}")
except:
    print(f"{RED}No tool call found{RESET}")