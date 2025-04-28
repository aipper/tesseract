# Stage 1: Builder
FROM python:3.13.3-slim-bullseye AS builder

# 设置环境变量
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    # 设置 uv 的国内镜像源 (推荐方式)
    UV_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple

WORKDIR /app

# 安装构建和运行时所需的系统依赖，并更换 apt 源
RUN sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        # RapidOCR (OpenCV) runtime dependencies
        libsm6 \
        libxext6 \
        # Potentially other build dependencies if needed, e.g., build-essential, git
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 安装 uv 并升级 pip
RUN pip install --no-cache-dir --upgrade pip uv -i https://pypi.tuna.tsinghua.edu.cn/simple

# 复制依赖定义文件
COPY pyproject.toml uv.lock ./

# 使用 uv 安装 Python 依赖
# 注意：uv sync 会安装 uv.lock 中锁定的所有依赖，包括开发依赖。
# 如果想只安装生产依赖，可能需要调整 pyproject.toml 或使用 uv pip install --no-deps -r requirements.txt (如果生成了)
# 或者确保 uv.lock 只包含生产环境需要的包。通常 uv sync 是正确的做法。
RUN uv sync --system # Use --system if you want packages available system-wide like pip install

# 运行 Python 代码触发模型下载 (默认下载到 /root/.RapidOCR)
# 确保 RapidOCR() 初始化确实将模型下载到 /root/.RapidOCR
RUN echo "from rapidocr import RapidOCR; print('Initializing OCR engine to download models...'); engine = RapidOCR(); print('Models downloaded.')" | python \
    && echo "Listing downloaded models:" \
    && ls -l /root/.RapidOCR \
    && echo "Cleanup build artifacts..." \
    && find /app -name '*.pyc' -delete \
    && find /app -name '__pycache__' -type d -delete \
    # 清理 uv 缓存（如果需要进一步减小 builder 层体积）
    # && rm -rf /root/.cache/uv

# Stage 2: Final Image
FROM python:3.13.3-slim-bullseye

# 设置环境变量
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# 安装运行时系统依赖 (从 builder 复制过来的 Python 包需要这些)
RUN sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        libsm6 \
        libxext6 \
    # 清理 apt 缓存
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 创建非 root 用户和组
RUN groupadd -r appuser && useradd --no-log-init -r -g appuser appuser \
    # 创建并授权缓存目录 (如果应用运行时需要写入缓存)
    && mkdir -p /home/appuser/.cache \
    && chown -R appuser:appuser /home/appuser \
    # 授权应用目录给新用户
    && chown -R appuser:appuser /app

# 复制 Python 环境和可执行文件
# ***注意这里修改了 Python 版本路径***
COPY --from=builder /usr/local/lib/python3.13/site-packages/ /usr/local/lib/python3.13/site-packages/
COPY --from=builder /usr/local/bin/ /usr/local/bin/

# 复制预先下载的 RapidOCR 模型，并设置权限
# 确保 /home/appuser 目录存在且权限正确
COPY --from=builder --chown=appuser:appuser /root/.RapidOCR /home/appuser/.RapidOCR

# 复制应用代码，并设置权限
COPY --chown=appuser:appuser . .

# 切换到非 root 用户
USER appuser

# 运行应用
CMD ["gunicorn", "-c", "gunicorn_config.py", "app:app"]