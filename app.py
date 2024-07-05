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


@app.route('/',methods=['POST'])
def hello_world():
    url = request.get_json().get('url')
    print('url:',url)
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
    text=pytesseract.image_to_string(img, lang='chi_sim')
    data = {
        "code": 200,
        # "result": "".join(checkStr(result))
        "result": text
    }
    return jsonify(data)


if __name__ == '__main__':
    app.run()
