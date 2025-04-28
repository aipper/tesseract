FROM python:3.13.3-slim-bullseye AS builder

# 设置环境变量
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
# 设置 uv 的国内镜像源 (推荐方式)
ENV UV_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple

# 设置工作目录
WORKDIR /app

RUN sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        libsm6 \
        libxext6 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir uv

COPY requirements.txt .
RUN uv pip sync requirements.txt --no-cache

# 运行 Python 代码触发模型下载
RUN python -c "from rapidocr import RapidOCR; print('Initializing OCR engine to download models...'); engine = RapidOCR(); print('Models should be downloaded.')" \
    && rm -f requirements.txt \
    && find /app -name '*.pyc' -delete \
    && find /app -name '__pycache__' -type d -delete


FROM python:3.13.3-slim-bullseye

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV UV_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple

WORKDIR /app

RUN groupadd -r appuser && useradd -r -g appuser appuser \
    && mkdir -p /home/appuser/.cache \
    && chown -R appuser:appuser /app /home/appuser

COPY --from=builder /usr/local/lib/python3.9/site-packages/ /usr/local/lib/python3.9/site-packages/
COPY --from=builder /usr/local/bin/ /usr/local/bin/

COPY --from=builder /root/.RapidOCR /home/appuser/.RapidOCR
RUN chown -R appuser:appuser /home/appuser/.RapidOCR

COPY --chown=appuser:appuser . .
USER appuser
CMD ["gunicorn", "-c", "gunicorn_config.py", "app:app"]