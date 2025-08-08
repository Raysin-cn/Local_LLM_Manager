#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Qwen2.5-VL-7B-Instruct LLM服务功能测试脚本
测试包括：文本生成、图像理解、多模态对话等功能
"""

import requests
import json
import base64
import time
from typing import Dict, Any, Optional
import os
from pathlib import Path


class QwenLLMTester:
    """Qwen2.5-VL-7B-Instruct LLM服务测试类"""
    
    def __init__(self, base_url: str = "http://localhost:12345"):
        """
        初始化测试器
        
        Args:
            base_url: LLM服务的基地址
        """
        self.base_url = base_url
        self.session = requests.Session()
        self.session.headers.update({
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        })
    
    def test_health_check(self) -> bool:
        """测试服务健康状态"""
        try:
            response = self.session.get(f"{self.base_url}/health")
            if response.status_code == 200:
                print("✅ 服务健康检查通过")
                return True
            else:
                print(f"❌ 服务健康检查失败: {response.status_code}")
                return False
        except Exception as e:
            print(f"❌ 服务连接失败: {e}")
            return False
    
    def test_text_generation(self, prompt: str = "请介绍一下人工智能的发展历史") -> bool:
        """测试纯文本生成功能"""
        try:
            payload = {
                "model": "Qwen2.5-VL-7B-Instruct",
                "messages": [
                    {"role": "user", "content": prompt}
                ],
                "max_tokens": 500,
                "temperature": 0.7
            }
            
            response = self.session.post(f"{self.base_url}/v1/chat/completions", json=payload)
            
            if response.status_code == 200:
                result = response.json()
                content = result['choices'][0]['message']['content']
                print(f"✅ 文本生成测试通过")
                print(f"📝 生成内容: {content[:200]}...")
                return True
            else:
                print(f"❌ 文本生成测试失败: {response.status_code}")
                print(f"错误信息: {response.text}")
                return False
        except Exception as e:
            print(f"❌ 文本生成测试异常: {e}")
            return False
    
    def test_image_understanding(self, image_path: str = None) -> bool:
        """测试图像理解功能"""
        try:
            # 如果没有提供图像路径，创建一个简单的测试图像描述
            if not image_path or not os.path.exists(image_path):
                print("⚠️  未找到测试图像，使用文本描述进行测试")
                payload = {
                    "model": "Qwen2.5-VL-7B-Instruct",
                    "messages": [
                        {"role": "user", "content": "请描述这张图片中的内容：[图片：一只可爱的小猫坐在花园里]"}
                    ],
                    "max_tokens": 300,
                    "temperature": 0.7
                }
            else:
                # 读取并编码图像
                with open(image_path, "rb") as img_file:
                    img_data = base64.b64encode(img_file.read()).decode('utf-8')
                
                payload = {
                    "model": "Qwen2.5-VL-7B-Instruct",
                    "messages": [
                        {
                            "role": "user",
                            "content": [
                                {
                                    "type": "image_url",
                                    "image_url": {
                                        "url": f"data:image/jpeg;base64,{img_data}"
                                    }
                                },
                                {"type": "text", "text": "请描述这张图片中的内容"}
                            ]
                        }
                    ],
                    "max_tokens": 300,
                    "temperature": 0.7
                }
            
            response = self.session.post(f"{self.base_url}/v1/chat/completions", json=payload)
            
            if response.status_code == 200:
                result = response.json()
                content = result['choices'][0]['message']['content']
                print(f"✅ 图像理解测试通过")
                print(f"📝 理解结果: {content[:200]}...")
                return True
            else:
                print(f"❌ 图像理解测试失败: {response.status_code}")
                print(f"错误信息: {response.text}")
                return False
        except Exception as e:
            print(f"❌ 图像理解测试异常: {e}")
            return False
    
    def test_multimodal_conversation(self) -> bool:
        """测试多模态对话功能"""
        try:
            # 模拟多轮对话，包含文本和图像
            conversation = [
                {"role": "user", "content": "你好，请介绍一下你自己"},
                {"role": "assistant", "content": "你好！我是Qwen2.5-VL，一个多模态大语言模型。我可以理解和处理文本、图像等多种信息。"},
                {
                    "role": "user", 
                    "content": [
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": "https://help-static-aliyun-doc.aliyuncs.com/file-manage-files/zh-CN/20241022/emyrja/dog_and_girl.jpeg"
                            }
                        },
                        {"type": "text", "text": "你能看到图像吗？请描述一下你看到的内容"}
                    ]
                }
            ]
            
            payload = {
                "model": "Qwen2.5-VL-7B-Instruct",
                "messages": conversation,
                "max_tokens": 400,
                "temperature": 0.7
            }
            
            response = self.session.post(f"{self.base_url}/v1/chat/completions", json=payload)
            
            if response.status_code == 200:
                result = response.json()
                content = result['choices'][0]['message']['content']
                print(f"✅ 多模态对话测试通过")
                print(f"📝 对话回复: {content[:200]}...")
                return True
            else:
                print(f"❌ 多模态对话测试失败: {response.status_code}")
                print(f"错误信息: {response.text}")
                return False
        except Exception as e:
            print(f"❌ 多模态对话测试异常: {e}")
            return False
    
    def test_code_generation(self) -> bool:
        """测试代码生成功能"""
        try:
            prompt = "请用Python编写一个简单的计算器函数，支持加减乘除四则运算"
            
            payload = {
                "model": "Qwen2.5-VL-7B-Instruct",
                "messages": [
                    {"role": "user", "content": prompt}
                ],
                "max_tokens": 600,
                "temperature": 0.3
            }
            
            response = self.session.post(f"{self.base_url}/v1/chat/completions", json=payload)
            
            if response.status_code == 200:
                result = response.json()
                content = result['choices'][0]['message']['content']
                print(f"✅ 代码生成测试通过")
                print(f"📝 生成代码: {content[:300]}...")
                return True
            else:
                print(f"❌ 代码生成测试失败: {response.status_code}")
                print(f"错误信息: {response.text}")
                return False
        except Exception as e:
            print(f"❌ 代码生成测试异常: {e}")
            return False
    
    def test_response_time(self) -> bool:
        """测试响应时间"""
        try:
            prompt = "请简要回答：什么是机器学习？"
            
            payload = {
                "model": "Qwen2.5-VL-7B-Instruct",
                "messages": [
                    {"role": "user", "content": prompt}
                ],
                "max_tokens": 100,
                "temperature": 0.7
            }
            
            start_time = time.time()
            response = self.session.post(f"{self.base_url}/v1/chat/completions", json=payload)
            end_time = time.time()
            
            response_time = end_time - start_time
            
            if response.status_code == 200:
                print(f"✅ 响应时间测试通过")
                print(f"⏱️  响应时间: {response_time:.2f}秒")
                return True
            else:
                print(f"❌ 响应时间测试失败: {response.status_code}")
                return False
        except Exception as e:
            print(f"❌ 响应时间测试异常: {e}")
            return False
    
    def run_all_tests(self) -> Dict[str, bool]:
        """运行所有测试"""
        print("🚀 开始Qwen2.5-VL-7B-Instruct LLM服务功能测试")
        print("=" * 60)
        
        test_results = {}
        
        # 1. 健康检查
        test_results['health_check'] = self.test_health_check()
        print("-" * 40)
        
        # 2. 文本生成测试
        test_results['text_generation'] = self.test_text_generation()
        print("-" * 40)
        
        # 3. 图像理解测试
        test_results['image_understanding'] = self.test_image_understanding("/home/lsj/Projects/Gittmp/droidrun/docs/favicon.png")
        print("-" * 40)
        
        # 4. 多模态对话测试
        test_results['multimodal_conversation'] = self.test_multimodal_conversation()
        print("-" * 40)
        
        # 5. 代码生成测试
        test_results['code_generation'] = self.test_code_generation()
        print("-" * 40)
        
        # 6. 响应时间测试
        test_results['response_time'] = self.test_response_time()
        print("-" * 40)
        
        # 输出测试总结
        self.print_test_summary(test_results)
        
        return test_results
    
    def print_test_summary(self, test_results: Dict[str, bool]):
        """打印测试总结"""
        print("\n" + "=" * 60)
        print("📊 测试结果总结")
        print("=" * 60)
        
        total_tests = len(test_results)
        passed_tests = sum(test_results.values())
        failed_tests = total_tests - passed_tests
        
        print(f"总测试数: {total_tests}")
        print(f"通过测试: {passed_tests}")
        print(f"失败测试: {failed_tests}")
        print(f"成功率: {(passed_tests/total_tests)*100:.1f}%")
        
        print("\n详细结果:")
        for test_name, result in test_results.items():
            status = "✅ 通过" if result else "❌ 失败"
            print(f"  {test_name}: {status}")
        
        if failed_tests == 0:
            print("\n🎉 所有测试都通过了！LLM服务运行正常。")
        else:
            print(f"\n⚠️  有 {failed_tests} 个测试失败，请检查服务配置。")


def main():
    """主函数"""
    # 创建测试器实例
    tester = QwenLLMTester()
    
    # 运行所有测试
    results = tester.run_all_tests()
    
    # 返回测试结果（用于脚本调用）
    return results


if __name__ == "__main__":
    main()
