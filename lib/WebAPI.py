from flask import Flask, jsonify, Response, request
import pandas as pd
import urllib.parse
import json
import os
import hashlib
from flask_cors import CORS
from werkzeug.serving import WSGIRequestHandler
import subprocess

app = Flask(__name__)
CORS(app)

# ========= 配置 =========
BANNED_IP_FILE = './banned_ips.txt'
WHITELIST_FILE = './whitelist.txt'
USER_DATA_FILE = './data/users.json'
DATA_FOLDER = './data'

# ========= 初始化白名单和封禁记录文件 =========
def ensure_file(file_path):
    if not os.path.exists(file_path):
        with open(file_path, 'w') as f:
            f.write('')

ensure_file(BANNED_IP_FILE)
ensure_file(WHITELIST_FILE)

# ========= IP 工具函数 =========
def load_ip_list(path):
    with open(path, 'r') as f:
        return set(line.strip() for line in f if line.strip())

def is_ip_banned(ip):
    return ip in load_ip_list(BANNED_IP_FILE)

def is_ip_whitelisted(ip):
    return ip in load_ip_list(WHITELIST_FILE)

def ban_ip(ip):
    if is_ip_whitelisted(ip) or is_ip_banned(ip):
        return
    subprocess.run(["iptables", "-A", "INPUT", "-s", ip, "-j", "DROP"])
    with open(BANNED_IP_FILE, 'a') as f:
        f.write(ip + '\n')
    print(f"[已封禁] IP：{ip}")

# ========= 中间件：请求前检查 =========
@app.before_request
def detect_bad_request():
    if request.environ.get('REMOTE_ADDR'):
        ip = request.environ['REMOTE_ADDR']
        try:
            data = request.get_data()
            if data.startswith(b'\x03\x00') or b'mstshash=' in data or b'\x16\x03\x01' in data:
                ban_ip(ip)
                return "请求非法，已封禁", 403
        except Exception:
            pass

# ========= API 路由 =========
tiles_data = [
    {"title": "0415物理类", "description": "这是湖北省四月调研考试物理类成绩", "extraInfo": "请文明查分"},
    {"title": "0313物理类", "description": "这是湖北省圆创联盟三月考试物理类成绩", "extraInfo": "请文明查分"},
]

@app.route('/api/tiles', methods=['GET'])
def get_tiles():
    return jsonify([
        {key: (value if value is not None else "") for key, value in tile.items()}
        for tile in tiles_data
    ])

@app.route('/api/excel/stream/<filename>', methods=['GET'])
def get_excel_data_stream(filename):
    try:
        decoded_filename = urllib.parse.unquote(filename)
        file_path = os.path.join(DATA_FOLDER, f"{decoded_filename}.xlsx")
        df = pd.read_excel(file_path).fillna("")

        def generate():
            for _, row in df.iterrows():
                row_dict = {key: (value if value is not None else "") for key, value in row.to_dict().items()}
                yield json.dumps(row_dict) + '\n'

        return Response(generate(), content_type='application/json')
    except FileNotFoundError:
        return jsonify({"error": "文件未找到"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/usernames', methods=['GET'])
def get_usernames():
    users = load_user_data()
    registered_usernames = set(users.keys())
    excel_usernames = set()

    for filename in os.listdir(DATA_FOLDER):
        if filename.endswith('.xlsx'):
            df = pd.read_excel(os.path.join(DATA_FOLDER, filename))
            if '姓名' in df.columns:
                excel_usernames.update(df['姓名'].dropna().astype(str).str.strip())

    for username in excel_usernames - registered_usernames:
        initialize_user(username)

    return jsonify(list(excel_usernames))

# ========= 用户功能 =========
def initialize_user_data_file():
    ensure_file(USER_DATA_FILE)
    if os.path.getsize(USER_DATA_FILE) == 0:
        with open(USER_DATA_FILE, 'w') as f:
            json.dump({}, f)

def load_user_data():
    if os.path.exists(USER_DATA_FILE):
        with open(USER_DATA_FILE, 'r') as f:
            return json.load(f)
    return {}

def save_user_data(data):
    with open(USER_DATA_FILE, 'w') as f:
        json.dump(data, f)

def hash_password(password):
    return hashlib.sha256(password.encode()).hexdigest()

def initialize_user(username):
    users = load_user_data()
    if username not in users:
        users[username] = hash_password('0000')
        save_user_data(users)

@app.route('/api/register', methods=['POST'])
def register_user():
    data = request.json
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({'error': '用户名和密码不能为空'}), 400

    users = load_user_data()
    users[username] = hash_password(password)
    save_user_data(users)
    return jsonify({'message': '用户注册或密码更新成功'})

@app.route('/api/login', methods=['POST'])
def login_user():
    data = request.json
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({'error': '用户名和密码不能为空'}), 400

    users = load_user_data()
    if username not in users:
        return jsonify({'error': '用户名不存在'}), 404

    if users[username] == hash_password(password):
        return jsonify({'message': '登录成功'})
    else:
        return jsonify({'error': '密码错误'}), 401

# ========= 启动 =========
if __name__ == '__main__':
    initialize_user_data_file()
    WSGIRequestHandler.protocol_version = "HTTP/1.1"
    app.run(host='0.0.0.0', port=5001)
