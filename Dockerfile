# 使用道客云的NVIDIA CUDA镜像（中国镜像）- 使用12.6兼容你的驱动
FROM docker.m.daocloud.io/nvidia/cuda:12.6.3-cudnn-devel-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
# 配置torch hub缓存目录和信任设置
ENV TORCH_HOME=/root/.cache/torch
ENV TORCH_HUB_DIR=/root/.cache/torch/hub

WORKDIR /app

ARG EXTRAS
ARG HF_PRECACHE_DIR
ARG HF_TKN_FILE

# Ubuntu源配置（HTTP→HTTPS智能切换策略）
RUN echo "🇨🇳 配置Ubuntu镜像源..." && \
    # 备份原始源
    cp /etc/apt/sources.list /etc/apt/sources.list.backup 2>/dev/null || true && \
    # 使用阿里云镜像源
    echo 'deb http://mirrors.aliyun.com/ubuntu/ noble main restricted universe multiverse' > /etc/apt/sources.list && \
    echo 'deb http://mirrors.aliyun.com/ubuntu/ noble-updates main restricted universe multiverse' >> /etc/apt/sources.list && \
    echo 'deb http://mirrors.aliyun.com/ubuntu/ noble-backports main restricted universe multiverse' >> /etc/apt/sources.list && \
    echo 'deb http://mirrors.aliyun.com/ubuntu/ noble-security main restricted universe multiverse' >> /etc/apt/sources.list && \
    # 清理其他源配置
    rm -rf /etc/apt/sources.list.d/* 2>/dev/null || true && \
    # 更新包列表并安装ca-certificates
    apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates && \
    # 升级为HTTPS源
    sed -i 's|http://|https://|g' /etc/apt/sources.list && \
    apt-get update && \
    # 安装依赖包
    apt-get install -y --no-install-recommends \
        python3 \
        python3-pip \
        python3-venv \
        ffmpeg \
        git \
        build-essential \
        python3-dev && \
    rm -rf /var/lib/apt/lists/* && \
    echo "✅ Ubuntu源配置完成"

# 创建虚拟环境并配置pip镜像源
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# 配置pip使用中国镜像源
RUN echo "🇨🇳 配置pip镜像源..." && \
    pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple && \
    pip config set install.trusted-host pypi.tuna.tsinghua.edu.cn && \
    pip install --upgrade pip -i https://pypi.tuna.tsinghua.edu.cn/simple && \
    echo "✅ pip配置完成"

# 安装PyTorch - 使用官方CUDA源确保版本兼容性
RUN echo "🇨🇳 安装PyTorch (CUDA 12.6)..." && \
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu126 && \
    echo "✅ PyTorch安装完成"

COPY . .
COPY smart_start.py /app/smart_start.py
RUN chmod +x /app/smart_start.py

# Install WhisperLiveKit directly, allowing for optional dependencies
#   Note: For gates models, need to add your HF token. See README.md
#         for more details.
RUN echo "🇨🇳 安装WhisperLiveKit..." && \
    if [ -n "$EXTRAS" ]; then \
      echo "Installing with extras: [$EXTRAS]"; \
      (pip install --no-cache-dir whisperlivekit[$EXTRAS] -i https://pypi.tuna.tsinghua.edu.cn/simple || \
       pip install --no-cache-dir whisperlivekit[$EXTRAS] -i https://pypi.mirrors.ustc.edu.cn/simple || \
       pip install --no-cache-dir whisperlivekit[$EXTRAS] -i https://repo.huaweicloud.com/repository/pypi/simple || \
       pip install --no-cache-dir whisperlivekit[$EXTRAS]); \
    else \
      echo "Installing base package only"; \
      (pip install --no-cache-dir whisperlivekit -i https://pypi.tuna.tsinghua.edu.cn/simple || \
       pip install --no-cache-dir whisperlivekit -i https://pypi.mirrors.ustc.edu.cn/simple || \
       pip install --no-cache-dir whisperlivekit -i https://repo.huaweicloud.com/repository/pypi/simple || \
       pip install --no-cache-dir whisperlivekit); \
    fi && \
    echo "✅ WhisperLiveKit安装完成"

# 创建缓存目录并设置权限
RUN mkdir -p /root/.cache/torch/hub /root/.cache/huggingface/hub && \
    chmod -R 755 /root/.cache

# Enable in-container caching for Hugging Face models and torch hub
# Note: If running multiple containers, better to map a shared bucket. 
VOLUME ["/root/.cache/huggingface/hub", "/root/.cache/torch/hub"]

# or
# B) Conditionally copy a local pre-cache from the build context to the 
#    container's cache via the HF_PRECACHE_DIR build-arg.
#    WARNING: This will copy ALL files in the pre-cache location.

# Conditionally copy a cache directory if provided
RUN if [ -n "$HF_PRECACHE_DIR" ]; then \
      echo "Copying Hugging Face cache from $HF_PRECACHE_DIR"; \
      mkdir -p /root/.cache/huggingface/hub && \
      cp -r $HF_PRECACHE_DIR/* /root/.cache/huggingface/hub; \
    else \
      echo "No local Hugging Face cache specified, skipping copy"; \
    fi

# Conditionally copy a Hugging Face token if provided

RUN if [ -n "$HF_TKN_FILE" ]; then \
      echo "Copying Hugging Face token from $HF_TKN_FILE"; \
      mkdir -p /root/.cache/huggingface && \
      cp $HF_TKN_FILE /root/.cache/huggingface/token; \
    else \
      echo "No Hugging Face token file specified, skipping token setup"; \
    fi
    
# Expose port for the transcription server
EXPOSE 8000

ENTRYPOINT ["python3", "/app/smart_start.py"]