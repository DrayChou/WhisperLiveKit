#!/usr/bin/env python3
"""
WhisperLiveKit智能启动脚本
处理GitHub API限制和模型下载问题
"""
import os
import time
import subprocess
import sys
from pathlib import Path

def download_silero_vad_with_retry(max_retries=3, delay=5):
    """
    使用重试机制下载silero-vad模型
    """
    print("🚀 正在启动WhisperLiveKit...")
    
    for attempt in range(max_retries):
        try:
            print(f"📥 尝试下载silero-vad模型 (第 {attempt + 1}/{max_retries} 次)")
            
            import torch
            import warnings
            warnings.filterwarnings('ignore')
            
            # 尝试加载模型
            model, utils = torch.hub.load(
                repo_or_dir='snakers4/silero-vad', 
                model='silero_vad',
                trust_repo=True,
                verbose=False
            )
            print("✅ silero-vad模型加载成功！")
            return True
            
        except Exception as e:
            print(f"⚠️  尝试 {attempt + 1} 失败: {str(e)}")
            if "rate limit" in str(e).lower():
                print(f"🕐 遇到速率限制，等待 {delay} 秒后重试...")
                time.sleep(delay)
                delay *= 2  # 指数退避
            elif "403" in str(e):
                print("🕐 GitHub API限制，等待后重试...")
                time.sleep(delay)
                delay *= 2
            else:
                print(f"❌ 其他错误: {e}")
                time.sleep(delay)
    
    print("❌ 无法下载silero-vad模型，将尝试启动服务...")
    return False

def main():
    """
    主启动函数
    """
    print("🎯 WhisperLiveKit 智能启动器")
    print("=" * 50)
    
    # 设置环境变量
    os.environ['TORCH_HOME'] = '/root/.cache/torch'
    os.environ['TORCH_HUB_DIR'] = '/root/.cache/torch/hub'
    
    # 确保缓存目录存在
    Path('/root/.cache/torch/hub').mkdir(parents=True, exist_ok=True)
    Path('/root/.cache/huggingface/hub').mkdir(parents=True, exist_ok=True)
    
    # 尝试预下载模型
    download_silero_vad_with_retry()
    
    # 启动WhisperLiveKit服务
    print("🚀 启动WhisperLiveKit服务...")
    try:
        cmd = [
            'whisperlivekit-server',
            '--host', '0.0.0.0',
            '--model', 'medium'
        ]
        subprocess.run(cmd, check=True)
    except KeyboardInterrupt:
        print("\n👋 服务已停止")
    except Exception as e:
        print(f"❌ 服务启动失败: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()