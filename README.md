Flutter_Project
一个基于 Flutter 与 Flask 的跨平台应用，提供用户登录、密码修改、成绩查询以及服务器端的 IP 封禁与白名单控制功能。

🚀 项目功能
📱 客户端（Flutter）
用户登录与注册：支持从 Excel 加载用户名，密码采用 SHA-256 加密。

首次登录修改密码：强制用户首次登录时修改默认密码。

成绩查询界面：通过后端接口从 Excel 动态读取成绩数据。

用户个人中心：展示用户头像、用户名，并提供退出登录功能。

🖥️ 服务器端（Flask）
用户管理：从 Excel 动态加载用户名，并支持注册与登录功能。

成绩数据接口：以 RESTful API 形式提供成绩查询。

IP 安全控制：

自动检测非法请求并封禁 IP。

支持设置白名单 IP，跳过封禁检测。

被封禁的 IP 会自动写入文件。

📁 文件结构
Flutter_Project/
├── lib/                      # Flutter 应用代码
│   ├── main.dart             # 主入口
│   ├── login_page.dart       # 登录页
│   ├── change_password_page.dart # 修改密码页
│   ├── profile_page.dart     # 个人信息页
│   ├── settings_page.dart    # 设置页
│   ├── excel_page.dart       # 成绩查询页
│   └── WebAPI.py             # Flask 后端服务
├── data/                     # 数据目录
│   ├── users.json            # 用户数据（加密存储）
│   ├── banned_ips.txt        # 封禁 IP 列表
│   ├── whitelist.txt         # 白名单 IP 列表
│   └── example.xlsx          # 示例 Excel 成绩表
├── README.md                 # 项目说明文件
└── pubspec.yaml              # Flutter 依赖配置

⚙️ 使用说明
运行前准备
安装 Flutter
安装 Python 3.x，并执行：
pip install flask pandas flask-cors openpyxl
启动方式
克隆项目并进入目录：
git clone https://github.com/Yao0454/Flutter_Project.git
cd Flutter_Project
启动 Flask 后端服务：
python lib/WebAPI.py
启动 Flutter 前端应用：
flutter pub get
flutter run
🔐 安全策略
🛡️ IP 封禁机制：自动识别恶意请求并将其 IP 写入封禁列表。

✅ 白名单机制：白名单中的 IP 不会被封禁。

🔒 密码加密：所有密码均使用 SHA-256 方式安全存储。

📄 开源协议
本项目采用 MIT License 开源协议，详情请见 LICENSE 文件。

