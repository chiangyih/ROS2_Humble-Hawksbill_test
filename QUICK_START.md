# ROS 2 一鍵部署 — 快速啟動指南

## ⚡ 五步快速部署

### 步驟 1️⃣: 進入部署目錄
```bash
cd ~/ros2_deployment/scripts
```

### 步驟 2️⃣: 執行一鍵部署
```bash
bash all-in-one-deploy.sh
```

> ⏱️ **耐心等候** 15-40 分鐘（取決於網路）

### 步驟 3️⃣: 驗證部署
```bash
bash verify-deployment.sh
```

> 應該看到 `✓ 系統驗證通過！`

### 步驟 4️⃣: 啟動 ROS 環境
```bash
bash start-ros2.sh
```

### 步驟 5️⃣: 測試 ROS 2
在新的 ROS shell 中執行：
```bash
ros2 node list
ros2 topic list
```

---

## 🎯 一行腳本啟動多個終端

### 終端 1: ROS 環境
```bash
bash start-ros2.sh
```

### 終端 2: micro-ROS Agent (在新 shell 中)
```bash
bash start-microros-agent.sh
```

### 終端 3: ROS 命令 (在 ROS shell 中)
```bash
ros2 topic list
ros2 node list
```

---

## 📋 指令碼功能速查表

| 指令碼 | 用途 | 執行時間 |
|--------|------|---------|
| `all-in-one-deploy.sh` | 完整部署（安裝所有組件） | 15-40 分鐘 |
| `verify-deployment.sh` | 驗證所有組件是否正確安裝 | 10 秒 |
| `start-ros2.sh` | 快速啟動 ROS 2 環境 | 2 秒 |
| `start-microros-agent.sh` | 啟動 UDP micro-ROS Agent | 1 秒 |
| `clean.sh` | 清潔緩存與構建產物 | 1 秒 |

---

## 🆘 遇到問題?

### 檢查部署日誌
```bash
tail -50 ~/ros2_deployment.log
```

### 重新驗證系統
```bash
bash verify-deployment.sh
```

### 查看詳細幫助
```bash
cat README.md
```

### 清潔重新安裝
```bash
bash clean.sh all
bash all-in-one-deploy.sh
```

---

## ✅ 成功標誌

部署成功時，應該能執行:

```bash
# 啟動 ROS
bash start-ros2.sh

# 在 ROS shell 中執行
ros2 node list
ros2 topic list

# 在另一個終端
bash start-microros-agent.sh
# 應該看到: [UDP Agent] Running at port 8888
```

---

## 🚀 下一步

部署完成後：

1. **閱讀完整文檔**
   ```bash
   cat DEPLOYMENT_SUCCESS.md
   cat DEPLOYMENT_GUIDE.md
   ```

2. **建立自己的項目**
   ```bash
   cd ~/ros2_ws/src
   ros2 pkg create my_package
   ```

3. **編譯與測試**
   ```bash
   cd ~/ros2_ws
   colcon build --symlink-install
   source install/setup.bash
   ```

4. **探索 ROS 2**
   ```bash
   # 列出可用的示例
   ros2 pkg list | grep demo
   
   # 執行 demo
   ros2 run demo_nodes_cpp listener &
   ros2 run demo_nodes_cpp talker
   ```

---

## 💾 目錄結構

```
~/ros2_deployment/
├── scripts/                    # 本目錄（所有可執行指令碼）
│   ├── all-in-one-deploy.sh   # 🔴 主部署指令碼
│   ├── verify-deployment.sh   # 驗證工具
│   ├── start-ros2.sh          # ROS 啟動
│   ├── start-microros-agent.sh# micro-ROS 啟動
│   ├── clean.sh               # 清潔工具
│   └── README.md              # 完整文檔
├── config/
│   └── cyclonedds.xml         # DDS 配置
├── launch/
│   └── robot_system.launch.py # 啟動檔案
└── *.md                       # 部署指南
```

---

## 📝 記住這些關鍵命令

```bash
# 啟動 ROS 環境
bash ~/ros2_deployment/scripts/start-ros2.sh

# 啟動 micro-ROS Agent
bash ~/ros2_deployment/scripts/start-microros-agent.sh

# 進入工作區
cd ~/ros2_ws

# 編譯工作區
colcon build --symlink-install

# 查看節點
ros2 node list

# 查看話題
ros2 topic list

# 訂閱話題
ros2 topic echo <topic_name>
```

---

**祝部署成功！任何問題都可參考完整文檔。** 🎉
