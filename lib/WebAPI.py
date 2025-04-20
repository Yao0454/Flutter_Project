from flask import Flask, jsonify, Response, request
import pandas as pd
import urllib.parse  # 用于解码 URL 编码的文件名
import json
import os  # 用于列出目录中的文件
import hashlib  # 用于加密密码
from flask_cors import CORS

app = Flask(__name__)
CORS(app)  # 启用跨域支持

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

# 提取所有 Excel 文件中的姓名列的并集
@app.route('/api/usernames', methods=['GET'])
def get_usernames():
    # 从 JSON 文件中加载已注册的用户名
    users = load_user_data()
    registered_usernames = set(users.keys())

    # 从所有 Excel 文件中提取姓名列的并集
    excel_usernames = set()
    for filename in os.listdir('./data'):  # 假设 Excel 文件存储在 ./data 目录下
        if filename.endswith('.xlsx'):
            df = pd.read_excel(f'./data/{filename}')
            if '姓名' in df.columns:
                excel_usernames.update(df['姓名'].dropna().astype(str).str.strip().tolist())

    # 初始化未注册的用户名
    for username in excel_usernames - registered_usernames:
        initialize_user(username)

    return jsonify(list(excel_usernames))

#用户名数据库
USER_DATA_FILE = './data/users.json'

# 检查并创建空的 JSON 文件
def initialize_user_data_file():
    if not os.path.exists(USER_DATA_FILE):
        with open(USER_DATA_FILE, 'w') as file:
            json.dump({}, file)  # 写入一个空的 JSON 对象

# 加载用户数据
def load_user_data():
    if os.path.exists(USER_DATA_FILE):
        with open(USER_DATA_FILE, 'r') as file:
            return json.load(file)
    return {}

# 保存用户数据
def save_user_data(data):
    with open(USER_DATA_FILE, 'w') as file:
        json.dump(data, file)

# 哈希密码
def hash_password(password):
    return hashlib.sha256(password.encode()).hexdigest()

# 初始化用户
def initialize_user(username):
    users = load_user_data()
    if username not in users:
        users[username] = hash_password('0000')  # 设置初始密码为 0000
        save_user_data(users)

# 注册或更新密码
@app.route('/api/register', methods=['POST'])
def register_user():
    data = request.json
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({'error': '用户名和密码不能为空'}), 400

    users = load_user_data()
    users[username] = hash_password(password)  # 更新或添加用户名和密码
    save_user_data(users)

    return jsonify({'message': '用户注册或密码更新成功'})

# 验证密码
@app.route('/api/login', methods=['POST'])
def login_user():
    data = request.json
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({'error': '用户名和密码不能为空'}), 400

    users = load_user_data()
    hashed_password = users.get(username)

    # 检查用户名是否存在
    if not hashed_password:
        return jsonify({'error': '用户名不存在'}), 404

    # 检查密码是否匹配
    if hashed_password == hash_password(password):
        return jsonify({'message': '登录成功'})
    else:
        return jsonify({'error': '密码错误'}), 401

if __name__ == '__main__':
    initialize_user_data_file()  # 初始化用户数据文件
    app.run(host='0.0.0.0', port=5001)

