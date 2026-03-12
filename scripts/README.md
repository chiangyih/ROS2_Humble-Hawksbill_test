# ROS 2 一鍵部署指令檔套件

## 📋 概述

本套件提供完整的**一鍵自動化部署解決方案**，可在 WSL2 Ubuntu 22.04 上快速部署 ROS 2 Humble + micro-ROS 開發環境。

**特點**:
- ✅ **完全自動化** — 無需手動干預
- ✅ **本地安裝** — 無需 Docker
- ✅ **完整驗證** — 包含系統檢查與診斷
- ✅ **快速啟動** — 簡化環境配置
- ✅ **易於管理** — 提供清潔與重置工具

---

## 🚀 快速開始（3 步）

### 步驟 1: 賦予執行權限
```bash
cd ~/ros2_deployment/scripts
chmod +x *.sh
```

### 步驟 2: 執行一鍵部署
```bash
bash all-in-one-deploy.sh
```

### 步驟 3: 驗證部署成功
```bash
bash verify-deployment.sh
```

---

## 📁 指令檔清單

### 1. `all-in-one-deploy.sh` — 主部署指令檔

**用途**: 執行完整的一鍵部署流程

**功能**:
- ✓ 系統環境檢查
- ✓ 基礎套件安裝與系統更新
- ✓ ROS 2 Humble 安裝（優先套件庫，備選源碼編譯）
- ✓ micro-ROS 工具鏈安裝
- ✓ ROS 2 工作區建立與編譯
- ✓ 環境變數配置
- ✓ 系統驗證

**執行時間**: ~20-40 分鐘（取決於網路與系統配置）

**使用方式**:
```bash
bash all-in-one-deploy.sh
```

**日誌**:
- 完整日誌存儲在 `~/ros2_deployment.log`

**預期輸出**:
```
✓ Ubuntu 系統驗證通過
✓ 基礎系統套件安裝完成
✓ ROS 2 Humble 安裝完成
✓ micro-ROS 工具安裝完成
✓ 工作區編譯完成
✓ 系統驗證完成
```

---

### 2. `verify-deployment.sh` — 部署驗證檢查

**用途**: 檢查所有組件是否正確安裝

**檢查項目**:
- ✓ 系統環境 (OS, 磁碟, 權限)
- ✓ ROS 2 Humble 安裝
- ✓ 編譯工具 (colcon, cmake, git, rosdep)
- ✓ 工作區狀態
- ✓ 網路連接與 DNS
- ✓ micro-ROS 工具
- ✓ ROS 通訊

**執行時間**: ~10-15 秒

**使用方式**:
```bash
bash verify-deployment.sh
```

**預期輸出**:
```
✓ Ubuntu 系統
✓ 磁碟空間
✓ ros2 命令
✓ colcon 構建工具
...
✓ 系統驗證通過
```

---

### 3. `start-ros2.sh` — ROS 2 快速啟動

**用途**: 簡化 ROS 2 環境配置與啟動

**功能**:
- ✓ 啟用 ROS 2 Humble 環境
- ✓ 加載 ROS 2 工作區
- ✓ 啟用 micro-ROS (如果可用)
- ✓ 設定環境變數
- ✓ 啟動交互式 shell

**執行時間**: ~2 秒

**使用方式**:
```bash
bash start-ros2.sh
```

**效果**: 開啟新的 shell，所有 ROS 環境變數已預配置

**立即可用的命令**:
```bash
ros2 node list
ros2 topic list
colcon build --symlink-install
```

---

### 4. `start-microros-agent.sh` — micro-ROS Agent 啟動

**用途**: 快速啟動本地 UDP micro-ROS Agent

**功能**:
- ✓ 啟用 ROS 2 + micro-ROS 環境
- ✓ 檢查 UDP 埠可用性
- ✓ 啟動 UDP 監聽代理

**執行時間**: ~1 秒

**使用方式**:
```bash
# 使用預設埠 8888
bash start-microros-agent.sh

# 使用自訂埠（例: 8889）
bash start-microros-agent.sh 8889
```

**預期輸出**:
```
✓ ROS 2 Humble 環境已啟用
✓ micro-ROS 環境已啟用
✓ 埠 8888 可用
▸ 啟動 micro-ROS UDP Agent...
[UDP Agent] Running at port 8888
```

**停止**: 按 `CTRL+C`

---

### 5. `clean.sh` — 清潔與重置工具

**用途**: 清潔構建產物、緩存與臨時檔案

**清潔選項**:

| 選項 | 說明 |
|------|------|
| `build` | 清潔 build/ 與 install/ 目錄 |
| `cache` | 清潔 ROS daemon 與日誌 |
| `colcon` | 清潔 colcon 快取配置 |
| `all` | 執行完全清潔 (需確認) |
| `help` | 顯示幫助信息 |

**使用方式**:
```bash
# 清潔構建檔案
bash clean.sh build

# 清潔所有快取
bash clean.sh all
```

---

## 🔄 典型工作流程

### 初始部署
```bash
# 1. 執行一鍵部署
bash all-in-one-deploy.sh

# 2. 驗證安裝
bash verify-deployment.sh

# 3. 啟動 ROS 環境
bash start-ros2.sh
```

### 日常開發
```bash
# 啟動 ROS 環境
bash start-ros2.sh

# 編譯工作區
colcon build --symlink-install

# 在另一個終端啟動 micro-ROS Agent
bash start-microros-agent.sh

# 使用 ROS 命令
ros2 topic list
ros2 node list
```

### 清潔與重新構建
```bash
# 清潔構建檔案
bash clean.sh build

# 重新檢查環境
bash verify-deployment.sh

# 執行部署
bash all-in-one-deploy.sh
```

---

## 🛠️ 環境變數

部署完成後，以下環境變數將被自動設定:

```bash
# ROS 2 環境
source /opt/ros/humble/setup.bash

# 工作區環境
source ~/ros2_ws/install/setup.bash

# micro-ROS 環境
source ~/microros_ws/install/setup.bash

# ROS 通訊配置
export ROS_DOMAIN_ID=0
export ROS_LOCALHOST_ONLY=0
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
```

### 永久配置

將以下行添加到 `~/.bashrc`:
```bash
source /opt/ros/humble/setup.bash
source ~/ros2_ws/install/setup.bash
export ROS_DOMAIN_ID=0
```

然後重啟終端或執行:
```bash
source ~/.bashrc
```

---

## 📊 資源需求

| 資源 | 最低需求 | 推薦配置 |
|------|----------|---------|
| 磁碟空間 | 5 GB | 10 GB |
| RAM | 2 GB | 4 GB |
| 網路 | 必須連接 | 寬頻網路 |
| CPU | 2 核 | 4 核+ |

---

## ⚠️ 常見問題

### Q1: 部署需要多長時間?

**A**: 取決於網路與系統:
- 軟體包安裝: 5-10 分鐘
- ROS 2 安裝 (套件庫): 5-10 分鐘
- ROS 2 安裝 (源碼編譯): 30-60 分鐘
- micro-ROS 編譯: 5-10 分鐘

### Q2: 無法連接到 repo.ros.org

**A**: 指令碼會自動回退到源碼編譯。這需要更多時間但最終結果相同。

### Q3: 出現 "Permission denied" 錯誤

**A**: 檢查檔案權限:
```bash
chmod +x ~/ros2_deployment/scripts/*.sh
```

### Q4: 如何更新 ROS 2?

**A**: 使用系統套件管理器:
```bash
sudo apt upgrade ros-humble-*
```

### Q5: 如何卸載 ROS 2?

**A**: 
```bash
sudo apt remove ros-humble-*
sudo apt autoremove
```

---

## 🔧 進階用法

### 自訂工作區位置

編輯 `all-in-one-deploy.sh`:
```bash
ROS2_WS="$HOME/custom_ros2_ws"  # 修改此行
```

### 使用不同的 RMW 實現

編輯 `start-ros2.sh`:
```bash
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp  # 改為 CycloneDDS
```

### 靜默執行 (CI/CD)

```bash
bash all-in-one-deploy.sh 2>&1 | tee deploy.log
```

---

## 📖 相關文檔

- **DEPLOYMENT_SUCCESS.md** — 部署成功說明書
- **DEPLOYMENT_GUIDE.md** — 4 階段完整部署指南
- **MICRO_ROS_DEPLOYMENT.md** — micro-ROS 部署細節

---

## 💡 使用提示

1. **保存日誌** — 部署完整日誌存儲在 `~/ros2_deployment.log`
2. **驗證每一步** — 執行 `verify-deployment.sh` 確保安裝正確
3. **定期更新** — 定期執行 `sudo apt update && apt upgrade`
4. **備份工作區** — 在進行大幅更改前備份工作區
5. **使用 watch** — 監視話題數據: `watch -n 1 'ros2 topic list'`

---

## 📞 支持與反饋

若遇到問題:
1. 查看日誌: `cat ~/ros2_deployment.log`
2. 執行驗證: `bash verify-deployment.sh`
3. 查看相關文檔

---

## 版本信息

- **ROS 2 版本** : Humble Hawksbill
- **micro-ROS 版本**: Humble
- **Ubuntu 版本**: 22.04 LTS
- **最後更新**: 2026-03-12

---

**祝您 ROS 2 開發順利！** 🚀
