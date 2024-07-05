from flask import Flask, request, jsonify
from PIL import Image
import requests
import pytesseract

app = Flask(__name__)


def checkStr(nested_list_or_tuple):
    results = []
    for i in nested_list_or_tuple:
        if isinstance(i, (list, tuple)):
            if len(i) > 1 and isinstance(i[1], (list, tuple)) and len(i[0]) > 1:
                if isinstance(i[1][0], str):
                    results.append(i[1][0] + "\n")
            results += checkStr(i)
    return results


@app.route('/')
def hello_world():
    url = "https://p1-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/bd502b5cafd44b26820a134ad2ea598c~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp"
    image = Image.open(requests.get(url, stream=True).raw)
    img = image.convert('L')
    threshold = 69
    table = []
    for i in range(256):
        if i < threshold:
            table.append(1)
        else:
            table.append(0)
    img = img.point(table, '1')
    img.save("1.png")
    text=pytesseract.image_to_string(Image.open('1.png'), lang='chi_sim')
    data = {
        "code": 200,
        # "result": "".join(checkStr(result))
        "result": text
    }
    return jsonify()


if __name__ == '__main__':
    app.run()
