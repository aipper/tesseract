# Stage 1: Builder
FROM python:3.13.3-slim-bullseye AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple

WORKDIR /app

RUN sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        libsm6 \
        libxext6 \
        libgl1-mesa-glx \
        libglib2.0-0 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir --upgrade pip uv -i https://pypi.tuna.tsinghua.edu.cn/simple

COPY pyproject.toml uv.lock ./

RUN echo "Attempting installation using 'uv pip install . --system'" && \
    uv pip install . -v --no-cache --system

# 运行 Python 代码确认初始化成功，但不再检查 /root/.RapidOCR
RUN echo "Verifying RapidOCR initialization..." && \
    python -c "from rapidocr import RapidOCR; print('Initializing OCR engine...'); engine = RapidOCR(); print('RapidOCR initialized successfully.')" && \
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
        libxext6 \
        libgl1-mesa-glx \
        libglib2.0-0 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN groupadd -r appuser && \
    useradd --no-log-init -r -g appuser appuser && \
    mkdir -p /home/appuser/.cache && \
    chown -R appuser:appuser /home/appuser && \
    chown -R appuser:appuser /app

# 复制 Python 环境 (包含 site-packages 里的 rapidocr 及其自带模型)
COPY --from=builder /usr/local/lib/python3.13/site-packages/ /usr/local/lib/python3.13/site-packages/
COPY --from=builder /usr/local/bin/ /usr/local/bin/

# --- !! 移除这一行：不再需要复制单独的模型目录 !! ---
# COPY --from=builder --chown=appuser:appuser /root/.RapidOCR /home/appuser/.RapidOCR

# 复制应用代码
COPY --chown=appuser:appuser . .

USER appuser

CMD ["gunicorn", "-c", "gunicorn_config.py", "app:app"]