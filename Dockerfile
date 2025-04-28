# Stage 1: Builder
FROM python:3.13.3-slim-bullseye AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple

WORKDIR /app

# 安装构建和运行时所需的系统依赖，并更换 apt 源
RUN sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        libsm6 \
        libxext6 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 安装 uv 并升级 pip
RUN pip install --no-cache-dir --upgrade pip uv -i https://pypi.tuna.tsinghua.edu.cn/simple

COPY pyproject.toml uv.lock ./

# 使用 uv 安装 Python 依赖
RUN uv sync

# --- !! 添加验证步骤 !! ---
# 检查 rapidocr 是否确实被 uv sync 安装了
RUN echo "Verifying rapidocr installation..." && \
    python -m pip show rapidocr && \
    # 或者尝试 uv 命令: uv pip show rapidocr
    echo "Rapidocr verification complete."
# --- !! 验证步骤结束 !! ---

# 运行 Python 代码触发模型下载 (改用 python -c)
RUN echo "Attempting to download RapidOCR models..." && \
    python -c "from rapidocr import RapidOCR; print('Initializing OCR engine to download models...'); engine = RapidOCR(); print('Models downloaded.')" && \
    echo "Listing downloaded models:" && \
    ls -l /root/.RapidOCR && \
    echo "Cleanup build artifacts..." && \
    find /app -name '*.pyc' -delete && \
    find /app -name '__pycache__' -type d -delete

# Stage 2: Final Image
FROM python:3.13.3-slim-bullseye

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# 安装运行时系统依赖
RUN sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        libsm6 \
        libxext6 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 创建非 root 用户和组
RUN groupadd -r appuser && \
    useradd --no-log-init -r -g appuser appuser && \
    mkdir -p /home/appuser/.cache && \
    chown -R appuser:appuser /home/appuser && \
    chown -R appuser:appuser /app

# 复制 Python 环境和可执行文件
COPY --from=builder /usr/local/lib/python3.13/site-packages/ /usr/local/lib/python3.13/site-packages/
COPY --from=builder /usr/local/bin/ /usr/local/bin/

# 复制预先下载的 RapidOCR 模型
COPY --from=builder --chown=appuser:appuser /root/.RapidOCR /home/appuser/.RapidOCR

# 复制应用代码
COPY --chown=appuser:appuser . .

# 切换到非 root 用户
USER appuser

# 运行应用
CMD ["gunicorn", "-c", "gunicorn_config.py", "app:app"]