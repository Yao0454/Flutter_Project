from flask import Flask, jsonify, Response
import pandas as pd
import urllib.parse  # 用于解码 URL 编码的文件名
import json

app = Flask(__name__)

# 模拟磁贴数据（保持不变）
tiles_data = [
    {"title": "0415物理类", "description": "这是湖北省四月调研考试物理类成绩", "extraInfo": "请文明查分"},
    {"title": "0313物理类", "description": "这是湖北省圆创联盟三月考试物理类成绩", "extraInfo": "请文明查分"},
]

# 定义 API 路由（磁贴数据）
@app.route('/api/tiles', methods=['GET'])
def get_tiles():
    # 替换磁贴数据中的 null 值为默认值
    processed_tiles = []
    for tile in tiles_data:
        processed_tile = {key: (value if value is not None else "") for key, value in tile.items()}
        processed_tiles.append(processed_tile)
    return jsonify(processed_tiles)

# 动态流式读取 Excel 文件
@app.route('/api/excel/stream/<filename>', methods=['GET'])
def get_excel_data_stream(filename):
    try:
        # 解码文件名
        decoded_filename = urllib.parse.unquote(filename)
        file_path = f"./data/{decoded_filename}.xlsx"

        # 读取 Excel 文件
        df = pd.read_excel(file_path)

        # 替换 NaN 值为默认值（空字符串）
        df = df.fillna("")  # 或者使用 df.fillna("N/A")

        # 流式生成 JSON 数据
        def generate():
            for _, row in df.iterrows():
                row_dict = row.to_dict()
                # 替换 null 值为默认值
                row_dict = {key: (value if value is not None else "") for key, value in row_dict.items()}
                yield json.dumps(row_dict) + '\n'

        return Response(generate(), content_type='application/json')
    except FileNotFoundError:
        return jsonify({"error": "文件未找到"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True, port=5001)  # 启动服务，使用端口 5001

