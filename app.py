from flask import Flask, request, jsonify
from PIL import Image
import requests
import pytesseract
import logging
import base64

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)


def readImage(image):
    # 使用 pytesseract 进行 OCR 识别
    text = pytesseract.image_to_string(image, lang='chi_sim')
    app.logger.info("text: %s", text)

    data = {
        "code": 200,
        "result": text
    }
    return jsonify(data)


@app.route('/file', methods=['POST'])
def files():
    file = request.files.get('file')
    if file is not None:
        return readImage(Image.open(file))
    else:
        return jsonify({"code": 400, "message": "file is required"}), 400


@app.route('/base64', methods=['POST'])
def base64():
    base64_str = base64.b64decode(request.get_json().get('base64'))
    image = Image.open(base64_str)
    return readImage(image)


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
