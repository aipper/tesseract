from PIL import Image
import cv2
import numpy as np
import os


def resize_and_replace_background(input_image_path, output_image_path, target_size=(480, 640), background_color='blue'):
    # 打开图片并调整尺寸
    image = Image.open(input_image_path)
    image = image.resize(target_size, Image.Resampling.LANCZOS)

    # 转换为 numpy 数组以便使用 OpenCV
    image_np = np.array(image)

    # 转换为 OpenCV 的 BGR 格式
    image_cv = cv2.cvtColor(image_np, cv2.COLOR_RGB2BGR)

    # 定义背景颜色
    if background_color == 'blue':
        bg_color = [255, 0, 0]  # BGR format for blue
    else:
        bg_color = [255, 255, 255]  # White background

    # 假设背景是接近白色的颜色，这里定义一个颜色范围
    lower_white = np.array([200, 200, 200])
    upper_white = np.array([255, 255, 255])

    # 创建掩膜，用于确定背景区域
    mask = cv2.inRange(image_cv, lower_white, upper_white)

    # 将背景替换为指定颜色
    image_cv[mask == 255] = bg_color

    # 转换回 RGB 格式
    image_cv = cv2.cvtColor(image_cv, cv2.COLOR_BGR2RGB)

    # 转换回 Pillow 图像
    final_image = Image.fromarray(image_cv)

    # 保存为证件照格式
    final_image.save(output_image_path, format='JPEG', quality=95)

    print(f"Image saved as {output_image_path}")



# 示例使用
resize_and_replace_background("/Users/ab/Desktop/1.jpg", "/Users/ab/Desktop/output.jpg", background_color='blue')
