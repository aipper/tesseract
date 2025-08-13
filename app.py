from flask import Flask, request, jsonify
from PIL import Image
from rapidocr import RapidOCR
import requests
import logging
import base64
import io
import gc
app = Flask(__name__)
logging.basicConfig(level=logging.INFO)


engine = RapidOCR()

from contextlib import contextmanager

@contextmanager
def image_context(image_source):
    """图像上下文管理器，确保资源释放"""
    image = None
    try:
        if isinstance(image_source, str):  # base64字符串
            decoded_bytes = base64.b64decode(image_source)
            image = Image.open(io.BytesIO(decoded_bytes))
        elif hasattr(image_source, 'read'):  # 文件对象
            image = Image.open(image_source)
        else:  # PIL Image对象
            image = image_source
        yield image
    finally:
        if image:
            image.close()
        gc.collect()  # 强制垃圾回收



def readImage(image):
    text = engine(image).txts
    app.logger.info("text: %s", text)
    data = {    
        "code": 200,
        "result": text
    }
    return jsonify(data)
@app.route('/test')
def test():
    return readImage(Image.open("1.jpg"))

@app.route('/file', methods=['POST'])
def files():
    file = request.files.get('file')
    if file is not None:
        with image_context(file) as image
        return readImage(image)
    else:
        return jsonify({"code": 400, "message": "file is required"}), 400


@app.route('/base64', methods=['POST'])
def process_base64():
    try:
        # 验证输入是否存在
        base64_str = request.get_json().get('base64')
        if not base64_str:
            return jsonify({'error': 'Base64 string is missing.'}), 400

        # 限制base64字符串的大小以防止DoS攻击
        if len(base64_str) > 10 * 1024 * 1024:  # 10MB as an example
            return jsonify({'error': 'Base64 string exceeds size limit.'}), 400

        with image_context(base64_str) as image
        return  readImage(image)

    except base64.binascii.Error:
        return jsonify({'error': 'Invalid Base64 format.'}), 400
    except IOError:
        return jsonify({'error': 'Failed to open the image.'}), 400
    except Exception as e:
        # 捕获其他潜在异常，并返回通用错误消息
        return jsonify({'error': f'An error occurred: {str(e)}'}), 500
    finally:
        gc.collect()


@app.route('/ocr', methods=['POST'])
def ocr():
    url = request.get_json().get('url')

    # 检查 URL 是否为空
    if not url:
        return jsonify({"code": 400, "message": "URL is required"}), 400
    try:
        # 获取图像
        response = requests.get(url, stream=True)
        response.raise_for_status()

        # 打开图像
        image = Image.open(response.raw)
        return readImage(image)
    except requests.exceptions.RequestException as e:
        return jsonify({"code": 400, "message": str(e)}), 400
    except Exception as e:
        return jsonify({"code": 500, "message": "An error occurred during OCR processing", "error": str(e)}), 500


if __name__ == '__main__':
    app.run(debug=True)
