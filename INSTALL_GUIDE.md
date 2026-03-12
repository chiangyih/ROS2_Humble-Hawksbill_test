# ROS 2 一鍵部署套件 — 完整說明書

## 📦 套件內容

本套件包含 **完整的自動化本地部署解決方案**，無需 Docker。

### 📊 套件統計
- ✅ **5 個可執行指令碼** (990+ 行代碼)
- ✅ **5 份詳細文檔**
- ✅ **自動化完整流程** (系統檢查 → 安裝 → 驗證)
- ✅ **快速啟動工具**

---

## 🚀 開始使用（3 步）

### 1️⃣ 進入腳本目錄
```bash
cd ~/ros2_deployment/scripts
```

### 2️⃣ 執行部署
```bash
bash all-in-one-deploy.sh
```

### 3️⃣ 驗證完成
```bash
bash verify-deployment.sh
```

✅ **完成！您已成功部署 ROS 2 + micro-ROS**

---

## 📁 檔案結構詳解

```
~/ros2_deployment/
├── 🔴 scripts/
│   ├── all-in-one-deploy.sh        [主要部署] 710 行
│   ├── verify-deployment.sh        [驗證工具] 310 行
│   ├── start-ros2.sh               [快速啟動] 75 行
│   ├── start-microros-agent.sh     [Agent 啟動] 85 行
│   ├── clean.sh                    [清潔工具] 120 行
│   └── README.md                   [詳細說明] 350 行
│
├── 📘 文檔指南
│   ├── QUICK_START.md              [快速入門] ⭐ 從這裡開始
│   ├── DEPLOYMENT_SUCCESS.md       [部署成功說明] 500+ 行
│   ├── DEPLOYMENT_GUIDE.md         [完整指南] 4 階段全覆蓋
│   └── MICRO_ROS_DEPLOYMENT.md     [micro-ROS 詳解] 3 大方案
│
├── config/
│   └── cyclonedds.xml              [DDS 配置] 可選
│
└── 其他
    ├── docker-compose.yml          [Docker 版本] 可選
    └── *.cpp, *.py                 [驅動代碼] 參考範例
```

---

## 📖 文檔導覽

| 文檔名稱 | 適合人群 | 內容概述 |
|--------|--------|--------|
| **QUICK_START.md** | 首次用戶 | 5 步快速部署、常見問題 |
| **scripts/README.md** | 所有用戶 | 指令碼詳細說明、工作流程 |
| **DEPLOYMENT_SUCCESS.md** | 已部署用戶 | 成功驗證、系統架構、後續步驟 |
| **DEPLOYMENT_GUIDE.md** | 進階用戶 | 4 階段深度講解、網路配置、故障排除 |
| **MICRO_ROS_DEPLOYMENT.md** | 專家用戶 | 3 種部署方案、效能優化 |

**建議閱讀順序**: QUICK_START → scripts/README → DEPLOYMENT_SUCCESS

---

## 🎯 核心指令碼說明

### `all-in-one-deploy.sh` (主要)
```
作用: 執行完整的一鍵部署
步驟: 系統檢查 → 套件安裝 → ROS 2 安裝 → 編譯
耗時: 20-40 分鐘
執行: bash all-in-one-deploy.sh
日誌: ~/ros2_deployment.log
```

### `verify-deployment.sh` (驗證)
```
作用: 驗證所有組件
檢查: 系統、ROS 2、工具、工作區、網路、micro-ROS
耗時: 10 秒
執行: bash verify-deployment.sh
```

### `start-ros2.sh` (啟動)
```
作用: 預配置 ROS 環境
功能: 啟用環境變數、加載工作區
耗時: 2 秒
執行: bash start-ros2.sh
```

### `start-microros-agent.sh` (Agent)
```
作用: 啟動 micro-ROS UDP Agent
埠號: 8888 (可自訂)
耗時: 1 秒
執行: bash start-microros-agent.sh [埠號]
```

### `clean.sh` (清潔)
```
作用: 清潔緩存與構建產物
選項: build, cache, colcon, all
耗時: 1 秒
執行: bash clean.sh [選項]
```

---

## ⚙️ 工作流程圖

```
┌─────────────────────────────────────────────────────┐
│         ROS 2 一鍵部署完整工作流程                   │
└─────────────────────────────────────────────────────┘

1️⃣ 初次安裝
   └─ bash all-in-one-deploy.sh
      ├─ 系統檢查
      ├─ 套件更新
      ├─ ROS 2 安裝
      ├─ micro-ROS 安裝
      ├─ 編譯工作區
      └─ 環境配置 ✓

2️⃣ 驗證部署
   └─ bash verify-deployment.sh
      ├─ 系統檢查
      ├─ ROS 2 驗證
      ├─ 工具驗證
      ├─ 通訊測試
      └─ 報告生成 ✓

3️⃣ 日常開發
   ├─ bash start-ros2.sh
   │  └─ ROS 環境啟動 ✓
   ├─ colcon build --symlink-install
   │  └─ 工作區編譯 ✓
   └─ ros2 run ... / ros2 topic list
      └─ 應用執行 ✓

4️⃣ micro-ROS 開發
   ├─ bash start-microros-agent.sh
   │  └─ UDP Agent 啟動 ✓
   ├─ 上傳 ESp32 / RPi 韌體
   │  └─ 客戶端連接 ✓
   └─ ros2 topic echo /sensors/imu
      └─ 數據接收 ✓

5️⃣ 系統維護
   ├─ bash verify-deployment.sh
   │  └─ 定期驗證 ✓
   ├─ bash clean.sh build
   │  └─ 清潔產物 ✓
   └─ updates
      └─ 系統更新 ✓
```

---

## 💾 快速參考

### 最常用的 4 個命令

```bash
# 命令 1: 一鍵部署 (第一次執行)
bash ~/ros2_deployment/scripts/all-in-one-deploy.sh

# 命令 2: 驗證部署 (確保一切正常)
bash ~/ros2_deployment/scripts/verify-deployment.sh

# 命令 3: 啟動 ROS (每次開始開發)
bash ~/ros2_deployment/scripts/start-ros2.sh

# 命令 4: 啟動 Agent (需要 micro-ROS 時)
bash ~/ros2_deployment/scripts/start-microros-agent.sh
```

### 基本 ROS 2 命令 (在 ROS shell 中)

```bash
# 列出節點
ros2 node list

# 列出話題
ros2 topic list

# 訂閱話題
ros2 topic echo /話題名

# 編譯工作區
colcon build --symlink-install

# 建立新套件
ros2 pkg create --build-type ament_cmake my_package
```

---

## 🔧 自訂配置

### 修改安裝位置

編輯 `all-in-one-deploy.sh` 開頭:
```bash
ROS2_WS="$HOME/my_ros2_workspace"  # 改為自訂路徑
```

### 修改 ROS 域 ID

編輯 `start-ros2.sh`:
```bash
export ROS_DOMAIN_ID=1  # 改為不同的 ID
```

### 修改 micro-ROS 埠

執行時指定:
```bash
bash start-microros-agent.sh 8889  # 使用埠 8889
```

---

## ✅ 檢查清單

### 首次安裝 ✓
- [ ] 進入 `~/ros2_deployment/scripts`
- [ ] 執行 `bash all-in-one-deploy.sh`
- [ ] 等待 20-40 分鐘
- [ ] 執行 `bash verify-deployment.sh`
- [ ] 看到 "✓ 系統驗證通過"

### 日常使用 ✓
- [ ] 執行 `bash start-ros2.sh`
- [ ] 在 ROS shell 中執行 `ros2 node list`
- [ ] 編譯工作區: `colcon build --symlink-install`
- [ ] 執行應用: `ros2 run <pkg> <node>`

### micro-ROS 開發 ✓
- [ ] 執行 `bash start-microros-agent.sh`
- [ ] 上傳韌體到 ESP32/RPi
- [ ] 檢查連接: `ros2 topic list`
- [ ] 接收數據: `ros2 topic echo /sensors/imu`

---

## 🆘 故障排除

### 問題 1: 部署卡住
**解決**: `CTRL+C` 停止，查看日誌:
```bash
tail -100 ~/ros2_deployment.log
```

### 問題 2: ROS 命令找不到
**解決**: 啟用環境:
```bash
source /opt/ros/humble/setup.bash
```

### 問題 3: 無法連接 micro-ROS
**解決**: 檢查埠:
```bash
netstat -ulnp | grep 8888
```

### 問題 4: 編譯失敗
**解決**: 清潔並重新構建:
```bash
bash ~/ros2_deployment/scripts/clean.sh build
colcon build --symlink-install
```

---

## 📞 支持資源

1. **查看日誌**
   ```bash
   cat ~/ros2_deployment.log
   ```

2. **執行診斷**
   ```bash
   bash ~/ros2_deployment/scripts/verify-deployment.sh
   ```

3. **閱讀文檔**
   ```bash
   cat ~/ros2_deployment/QUICK_START.md
   cat ~/ros2_deployment/scripts/README.md
   ```

4. **官方資源**
   - [ROS 2 Humble 官方文檔](https://docs.ros.org/en/humble/)
   - [micro-ROS 官方指南](https://github.com/micro-ROS)

---

## 🎓 學習路徑

### 初級 (0-1 週)
1. 執行 `QUICK_START.md`
2. 運行基本 ROS 2 命令
3. 瞭解工作區結構

### 中級 (1-2 週)
1. 閱讀 `DEPLOYMENT_GUIDE.md`
2. 建立自己的 ROS 2 套件
3. 學習發佈者/訂閱者模式

### 高級 (2+ 週)
1. 整合 HIWIN 機械手臂
2. 開發 micro-ROS 客戶端 (ESP32/RPi)
3. 實現視覺系統與座標變換

---

## 📊 系統需求與性能

| 指標 | 最低 | 推薦 |
|------|------|------|
| 磁碟空間 | 5 GB | 10 GB |
| RAM | 2 GB | 4 GB |
| CPU | 2 核 | 4 核+ |
| 網路 | 必須 | 寬頻 |
| 部署時間 | 20 min | 40 min |

---

## 🔐 安全提示

✓ **已默認配置**:
- 防火牆規則 (UDP 8888)
- 用戶權限管理
- 日誌檔案記錄

⚠️ **生產環境建議**:
- 配置額外防火牆規則
- 啟用 HTTPS/TLS 加密
- 設置容器隔離
- 定期備份

---

## 📈 後續擴展

本部署完成後，可進行以下擴展:

1. **硬體整合**
   - HIWIN 機械手臂
   - 視覺系統 (攝像頭)
   - 感測器 (IMU, 溫溼度...)

2. **功能增強**
   - MoveIt 2 運動規劃
   - RViz 可視化
   - TF 座標變換

3. **系統優化**
   - 實時內核
   - 性能監控
   - 負載均衡

---

## 📋 版本信息

- **ROS 2 版本**: Humble Hawksbill (LTS)
- **micro-ROS 版本**: Humble
- **Ubuntu 版本**: 22.04 LTS
- **WSL 版本**: WSL2
- **部署套件版本**: 1.0.0
- **最後更新**: 2026-03-12

---

## 🙏 感謝

本套件參考了以下開源項目的最佳實踐:
- ROS 2 官方文檔
- micro-ROS 官方指南
- Ubuntu 部署最佳實踐

---

## 📝 許可証

本部署套件采用 **Apache 2.0 許可証**

使用、修改、分發自由，但需保留許可声詞

---

## 🎉 祝您使用愉快！

有任何問題，請查看相關文檔或執行驗證命令。

**開始部署**:
```bash
cd ~/ros2_deployment/scripts
bash all-in-one-deploy.sh
```

---

**準備好了嗎？讓我們开始吧！** 🚀
