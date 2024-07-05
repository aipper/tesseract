# 使用指定版本的 Python 镜像
FROM python:3.9.18-slim-bullseye

# 设置工作目录
WORKDIR /app

# 将当前目录下的文件复制到工作目录
COPY requirements.txt .
# 替换阿里云源并安装所需软件包
RUN sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        tesseract-ocr \
        tesseract-ocr-chi-sim \
        ffmpeg \
        libsm6 \
        libxext6 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
  && pip install --no-cache-dir --upgrade pip -i https://pypi.tuna.tsinghua.edu.cn/simple \
  &&  pip install --no-cache-dir -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple\
    && pip install --no-cache-dir gunicorn gevent -i https://pypi.tuna.tsinghua.edu.cn/simple

# 复制应用程序代码到工作目录
COPY . .

# 设置启动命令
CMD ["gunicorn", "-c", "gunicorn_config.py", "app:app"]
