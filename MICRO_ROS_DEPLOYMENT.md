# micro-ROS Agent 部署方案详细指南

## 📋 目录

1. [架构与通讯原理](#架构与通讯原理)
2. [部署方案对比](#部署方案对比)
3. [方案 A: Docker 容器部署](#方案-a-docker-容器部署)
4. [方案 B: 主机直接部署](#方案-b-主机直接部署)
5. [方案 C: Raspberry Pi 部署](#方案-c-raspberry-pi-部署)
6. [网络配置与故障排除](#网络配置与故障排除)

---

## 架构与通讯原理

### micro-ROS 系统架构

```
ESP32/Raspberry Pi          PC 主機
─────────────────────    ────────────
 [ROS 用戶端]             [micro-ROS Agent]
   (micro_ros)              └─ DDS Bridge ─┐
     │                                      │
     │ UDP/Serial               ROS 2       │
     └─────────────────────────────────────┤
                                           V
                                  [ROS 2 節點]
                                    (DDS)
```

### 通讯流程

1. **ESP32/RPi** 運行 `micro_ros_client`，通過 UDP 發送序列化的 ROS 訊息
2. **micro-ROS Agent** 監聽 UDP 埠 (預設 8888)，接收來自客戶端的訊息
3. **DDS Bridge** 將訊息轉換為標準 ROS 2 訊息格式
4. **ROS 2 Master** (DDS) 負責訊息路由與發佈-訂閱

### 支援的傳輸協議

| 協議 | 延遲 | CPP 消耗 | 場景 | 備註 |
|------|------|----------|------|------|
| **UDP over IP** | 低 | 低 | WiFi 無線 | 推薦用於 ESP32 |
| **TCP over IP** | 中 | 中 | 有線網路 | 備用方案 |
| **Serial (UART)** | 高 | 高 | USB 連接 | 不推薦 WiFi 設備 |
| **CAN Bus** | 低 | 很低 | 工業網路 | 需要 CAN 介面 |

---

## 部署方案对比

### 方案评分表

| 評估項 | Docker | 主機直接 | Raspberry Pi |
|--------|--------|----------|-------------|
| **安裝複雜度** | ⭐⭐ | ⭐ | ⭐⭐⭐ |
| **隔離性** | ⭐⭐⭐⭐⭐ | ⭐ | ⭐⭐ |
| **網路性能** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **資源消耗** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ |
| **易維護性** | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ |
| **生產環境** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |

### 方案選擇建議

| 場景 | 推薦方案 | 原因 |
|------|--------|------|
| 開發測試 | **Docker** | 快速部署，易除錯 |
| 高靠度生產 | **主機直接** | 最少額外層次，延遲最低 |
| 分散式感測 | **Raspberry Pi** | 同時運行感測驅動與 Agent |
| 多代理系統 | **Docker Compose** | 容易擴展多個 Agent 實例 |

---

## 方案 A: Docker 容器部署

### A.1 快速啟動 (推薦用於開發)

#### 前置要求
```bash
# 檢查 Docker 安裝
docker --version
docker-compose --version

# 驗證網路連接
ping 192.168.1.1         # 跳過
ping 192.168.0.1         # HIWIN IP
```

#### 安裝與啟動

```bash
# 1. 複製已配置的 docker-compose.yml
cd ~/ros2_deployment
cat docker-compose.yml  # 檢查 micro_ros_agent 服務

# 2. 啟動 micro-ROS Agent 容器 (獨立)
docker-compose up -d micro_ros_agent

# 3. 驗證容器狀態
docker ps | grep micro_ros_agent
docker logs micro_ros_agent

# 4. 測試 UDP 連接
docker exec micro_ros_agent ss -ulnp | grep 8888

# 5. 驗證 ROS 節點
docker exec micro_ros_agent ros2 node list
```

### A.2 自訂 Docker 映像 (進階)

#### 建立 Dockerfile

```dockerfile
# Dockerfile
# 位置: ~/ros2_deployment/docker/Dockerfile.micro_ros_agent

FROM ros:humble-ros-core

# 安裝 micro-ROS 代理工具集
RUN apt-get update && apt-get install -y \
    micro-ros-agent \
    python3-pip \
    ros-humble-rmw-cyclonedds-cpp \
    && rm -rf /var/lib/apt/lists/*

# 設定環境變數
ENV ROS_DOMAIN_ID=0
ENV RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ENV MICRO_ROS_LOG_LEVEL=info

# 建立工作目錄
WORKDIR /ros2_ws

# 暴露 UDP 埠
EXPOSE 8888/udp

# 健康檢查
HEALTHCHECK --interval=10s --timeout=5s --retries=3 \
    CMD ros2 node list || exit 1

# 啟動指令
CMD ["micro_ros_agent", "udp4", "--port", "8888", "-v6"]
```

#### 構建與執行

```bash
# 1. 構建自訂映像
cd ~/ros2_deployment
docker build -f docker/Dockerfile.micro_ros_agent \
    -t micro-ros-agent:custom .

# 2. 運行容器 (Host 網路模式 - 推薦)
docker run -d \
    --name micro_ros_agent_custom \
    --network host \
    -e ROS_DOMAIN_ID=0 \
    -e RMW_IMPLEMENTATION=rmw_cyclonedds_cpp \
    -e MICRO_ROS_LOG_LEVEL=info \
    micro-ros-agent:custom

# 3. 運行容器 (Bridge 網路模式 - 需埠對應)
docker run -d \
    --name micro_ros_agent_bridge \
    -p 8888:8888/udp \
    -e ROS_DOMAIN_ID=0 \
    micro-ros-agent:custom

# 4. 檢查日誌
docker logs -f micro_ros_agent_custom
```

### A.3 docker-compose 整合配置

#### 優化的 docker-compose.yml 片段

```yaml
services:
  micro_ros_agent:
    image: microros/micro-ros-agent:humble
    container_name: micro_ros_agent
    
    # ===== 網路配置 =====
    network_mode: host  # Host 模式 → 最低延遲
    # 或使用 Bridge 模式 (如需隔離):
    # networks:
    #   - ros_network
    # ports:
    #   - "8888:8888/udp"
    
    # ===== 環境變數 =====
    environment:
      ROS_DOMAIN_ID: "0"
      RMW_IMPLEMENTATION: "rmw_cyclonedds_cpp"
      MICRO_ROS_LOG_LEVEL: "info"  # debug, info, warn, error
      MICRO_ROS_AGENT_VERBOSE: "true"
    
    # ===== 資源限制 =====
    deploy:
      resources:
        limits:
          cpus: '0.5'        # CPU 限制
          memory: 512M       # 記憶體限制
        reservations:
          memory: 256M
    
    # ===== 啟動策略 =====
    restart: on-failure:5
    healthcheck:
      test: ["CMD", "ros2", "node", "list"]
      interval: 10s
      timeout: 5s
      retries: 3
    
    # ===== 日誌配置 =====
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    
    # ===== 啟動指令 & 參數 =====
    command: >
      udp4 --port 8888 -v6
      # 其他選項:
      # tcp4 --port 8888        (TCP 模式)
      # serial --dev /dev/ttyUSB0 (串行模式)
```

#### 啟動與驗證

```bash
# 1. 後台啟動所有服務
docker-compose up -d

# 2. 監視 micro-ROS Agent 日誌
docker-compose logs -f micro_ros_agent

# 3. 驗證服務健康狀態
docker-compose ps

# 4. 進入容器進行除錯
docker-compose exec micro_ros_agent bash

# 5. 停止服務
docker-compose down
```

---

## 方案 B: 主機直接部署

### B.1 安裝 micro-ROS Agent

#### 從原始碼編譯 (推薦)

```bash
# 1. 建立工作區
mkdir -p ~/microros_ws/src
cd ~/microros_ws

# 2. 複製 micro-ROS Agent 源碼
git clone -b humble \
    https://github.com/micro-ROS/micro-ROS-Agent.git \
    src/micro-ROS-Agent

# 3. 安裝相依套件
sudo apt install -y \
    python3-rosdep \
    python3-colcon-common-extensions

# 4. 安裝 ROS 相依
rosdep install --from-paths src/ --ignore-src -y

# 5. 編譯
colcon build --symlink-install

# 6. 驗證安裝
source install/setup.bash
which micro_ros_agent
```

#### 使用二進制套件 (快速)

```bash
# 1. 安裝官方套件
sudo apt install ros-humble-micro-ros-agent

# 2. 驗證安裝
ros2 run micro_ros_agent micro_ros_agent --help

# 3. 查看版本
dpkg -l | grep micro-ros
```

### B.2 以獨立程序運行 Agent

#### 方式 1: 直接命令行

```bash
# UDP 模式 (推薦 ESP32/WiFi 設備)
micro_ros_agent udp4 --port 8888 -v6

# TCP 模式 (如需 TCP 連接)
micro_ros_agent tcp4 --port 8888 -v6

# 串行模式 (USB 連接)
micro_ros_agent serial --dev /dev/ttyUSB0 -v6

# 查看完整選項
micro_ros_agent --help
```

#### 方式 2: systemd 服務 (開機自啟)

```bash
# 1. 建立 systemd 服務檔案
sudo nano /etc/systemd/system/micro-ros-agent.service
```

```ini
[Unit]
Description=micro-ROS Agent Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=tseng
Group=tseng

# 設定環境變數
Environment="ROS_DOMAIN_ID=0"
Environment="RMW_IMPLEMENTATION=rmw_cyclonedds_cpp"

# 啟動命令
ExecStart=/home/tseng/microros_ws/install/bin/micro_ros_agent udp4 --port 8888 -v6

# 自動重啟
Restart=on-failure
RestartSec=10

# 日誌
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

```bash
# 2. 啟用服務
sudo systemctl daemon-reload
sudo systemctl enable micro-ros-agent.service
sudo systemctl start micro-ros-agent.service

# 3. 檢查狀態
sudo systemctl status micro-ros-agent.service

# 4. 查看日誌
sudo journalctl -u micro-ros-agent.service -f

# 5. 停止服務
sudo systemctl stop micro-ros-agent.service
```

#### 方式 3: 後台運行指令

```bash
# 使用 nohup
nohup micro_ros_agent udp4 --port 8888 -v6 > /tmp/micro_ros_agent.log 2>&1 &

# 使用 screen
screen -dmS micro_ros_agent micro_ros_agent udp4 --port 8888 -v6

# 使用 tmux
tmux new-session -d -s micro_ros "micro_ros_agent udp4 --port 8888 -v6"

# 查看背景程程
ps aux | grep micro_ros_agent
```

### B.3 設定與優化

#### 環境變數配置

```bash
# 編輯 ~/.bashrc 或 ~/.zshrc
nano ~/.bashrc

# 添加以下內容
export ROS_DOMAIN_ID=0
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export RMW_DDS_TRANSPORT_CUBIC_ENABLE=true
export CYCLONEDDS_URI=file:///etc/cyclonedds.xml

# 應用變更
source ~/.bashrc
```

#### 性能調優

```bash
# A. Agent 詳細日誌 (除錯)
MICRO_ROS_AGENT_LOG_LEVEL=debug micro_ros_agent udp4 --port 8888

# B. 增加客戶端數量 (多設備)
# 預設: 10 儲存槽
# 可在 colcon build 時指定: --cmake-args -DCLIENT_STORAGE_SIZE=20

# C. 增加訊息緩衝區
# 編輯源碼中的配置檔案後重新編譯
```

---

## 方案 C: Raspberry Pi 部署

### C.1 Raspberry Pi 上安裝 ROS 2 + micro-ROS Agent

#### 硬體需求

```
Raspberry Pi 4B 或更高
- ARM64 位元組建築
- 4 GB RAM 以上 (建議 8 GB)
- 32 GB microSD 卡
- 良好的散熱 (風扇或散熱片)
```

#### 安裝步驟

```bash
# 1. SSH 連接到 Raspberry Pi
ssh pi@192.168.1.102

# 2. 更新系統
sudo apt update && sudo apt upgrade -y

# 3. 安裝 ROS 2 Humble (ARM64)
# 方法 A: 使用官方套件 (推薦)
sudo apt install curl gnupg2 lsb-release ubuntu-keyring

curl -sSL https://repo.ros.org/ros.key | sudo apt-key add -
sudo apt-add-repository "deb http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main"
sudo apt install ros-humble-ros-core -y

# 方法 B: 從原始碼編譯 (較慢但相容性好)
git clone https://github.com/ros2/ros2.git -b humble
cd ros2
mkdir src
cd src
vcs import < ../ros2.repos
cd ..
colcon build --symlink-install --packages-skip rclpy

# 4. 安裝 micro-ROS Agent
sudo apt install ros-humble-micro-ros-agent -y

# 5. 配置環境
echo "source /opt/ros/humble/setup.bash" >> ~/.bashrc
echo "export ROS_DOMAIN_ID=0" >> ~/.bashrc
echo "export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp" >> ~/.bashrc
source ~/.bashrc

# 6. 驗證安裝
ros2 --version
ros2 run micro_ros_agent micro_ros_agent --help
```

### C.2 Raspberry Pi 作為 Agent + 感測駕馭者

#### 統合配置腳本

```bash
#!/bin/bash
# rpi_setup.sh
# 作用: 在 Raspberry Pi 上完整配置 ROS 2 + Agent + 感測器驅動

set -e

echo "=========================================="
echo "Raspberry Pi ROS 2 + micro-ROS 完整配置"
echo "=========================================="

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. 系統準備
echo -e "${YELLOW}[步驟 1] 系統更新${NC}"
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl wget python3-pip
pip3 install --upgrade pip setuptools

# 2. 安裝 ROS 2
echo -e "${YELLOW}[步驟 2] 安裝 ROS 2 Humble${NC}"
sudo apt install -y ros-humble-desktop-full
echo "source /opt/ros/humble/setup.bash" >> ~/.bashrc

# 3. 安裝 micro-ROS Agent
echo -e "${YELLOW}[步驟 3] 安裝 micro-ROS Agent${NC}"
sudo apt install -y ros-humble-micro-ros-agent

# 4. 安裝感測器驅動依賴
echo -e "${YELLOW}[步驟 4] 安裝感測器驅動${NC}"
sudo apt install -y \
    python3-gpiozero \
    python3-rpi.gpio \
    i2c-tools \
    libi2c-dev

pip3 install \
    RPi.GPIO \
    adafruit-circuitpython-adxl34x \
    adafruit-circuitpython-busdevice

# 5. 配置 GPIO 權限
echo -e "${YELLOW}[步驟 5] 配置權限${NC}"
sudo usermod -aG gpio pi
sudo usermod -aG spi pi
sudo usermod -aG i2c pi
sudo usermod -aG video pi

# 6. 建立工作區
echo -e "${YELLOW}[步驟 6] 建立 ROS 工作區${NC}"
mkdir -p ~/ros2_ws/src
cd ~/ros2_ws

# 複製感測驅動
git clone https://github.com/your_user/ros2_sensor_drivers.git src/

# 7. 建立 systemd 服務
echo -e "${YELLOW}[步驟 7] 配置 systemd 服務${NC}"
sudo tee /etc/systemd/system/micro-ros-agent.service > /dev/null <<EOF
[Unit]
Description=micro-ROS Agent Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=pi
ExecStart=/opt/ros/humble/bin/micro_ros_agent udp4 --port 8888 -v6
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/rpi-sensor-driver.service > /dev/null <<EOF
[Unit]
Description=Raspberry Pi Sensor Driver
After=network-online.target micro-ros-agent.service
Wants=network-online.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/ros2_ws
ExecStart=/bin/bash -c "source /opt/ros/humble/setup.bash && ros2 run sensor_drivers rpi_sensor_driver"
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable micro-ros-agent.service
sudo systemctl enable rpi-sensor-driver.service

# 8. 完成
echo -e "${GREEN}=========================================="
echo "配置完成！"
echo "=========================================="
echo "請執行以下命令啟動服務:"
echo "  sudo systemctl start micro-ros-agent.service"
echo "  sudo systemctl start rpi-sensor-driver.service"
echo ""
echo "檢查狀態:"
echo "  sudo systemctl status micro-ros-agent.service"
echo "  sudo systemctl status rpi-sensor-driver.service"
echo -e "==========================================${NC}"
```

```bash
# 執行安裝指令碼
chmod +x rpi_setup.sh
./rpi_setup.sh
```

### C.3 Raspberry Pi micro-ROS 客戶端組態

#### Python 感測驅動範例 (with micro-ROS)

```python
#!/usr/bin/env python3
"""
Raspberry Pi micro-ROS 感測器驅動
同時作為: Sensor Driver + micro-ROS 客戶端
"""

import rclpy
from rclpy.node import Node
import socket
import struct
import json
from sensor_msgs.msg import Range
from std_msgs.msg import Float32, Bool
from geometry_msgs.msg import Vector3Stamped
import RPi.GPIO as GPIO
import time

class RpiMicroRosDriver(Node):
    """Raspberry Pi 感測器驅動 + ROS 2 發佈節點"""
    
    def __init__(self):
        super().__init__('rpi_micro_ros_driver')
        
        # GPIO 設定
        self.ULTRASONIC_TRIG = 17
        self.ULTRASONIC_ECHO = 22
        self.IR_SENSOR = 27
        GPIO.setmode(GPIO.BCM)
        GPIO.setup(self.ULTRASONIC_TRIG, GPIO.OUT)
        GPIO.setup(self.ULTRASONIC_ECHO, GPIO.IN)
        GPIO.setup(self.IR_SENSOR, GPIO.IN)
        
        # ROS 2 發佈者
        self.ultrasonic_pub = self.create_publisher(Range, 'sensors/ultrasonic', 10)
        self.ir_pub = self.create_publisher(Bool, 'sensors/infrared', 10)
        self.distance_pub = self.create_publisher(Float32, 'sensors/distance', 10)
        
        # 定期任務
        self.create_timer(0.1, self.sensor_callback)
        
        # micro-ROS 客戶端配置 (如需直接通訊到 Agent)
        self.agent_ip = '192.168.1.100'      # Agent 主機 IP
        self.agent_port = 8888                 # Agent UDP 埠
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        
        self.get_logger().info('Raspberry Pi micro-ROS 驅動已啟動')
    
    def read_ultrasonic(self):
        """讀取超音波感測器"""
        # 發送脈衝
        GPIO.output(self.ULTRASONIC_TRIG, False)
        time.sleep(0.000002)
        GPIO.output(self.ULTRASONIC_TRIG, True)
        time.sleep(0.00001)
        GPIO.output(self.ULTRASONIC_TRIG, False)
        
        # 計時
        timeout = time.time()
        while GPIO.input(self.ULTRASONIC_ECHO) == 0:
            if (time.time() - timeout) > 0.1:
                return None
        
        pulse_start = time.time()
        
        timeout = time.time()
        while GPIO.input(self.ULTRASONIC_ECHO) == 1:
            if (time.time() - timeout) > 0.1:
                return None
        
        pulse_end = time.time()
        
        # 計算距離
        distance = (pulse_end - pulse_start) * 17150.0
        return distance / 100.0  # 轉換為公尺
    
    def read_infrared(self):
        """讀取紅外線感測器"""
        return GPIO.input(self.IR_SENSOR) == 1
    
    def sensor_callback(self):
        """定期讀取感測器"""
        # 讀取超音波
        distance = self.read_ultrasonic()
        if distance:
            msg = Range()
            msg.header.stamp = self.get_clock().now().to_msg()
            msg.header.frame_id = 'ultrasonic_link'
            msg.radiation_type = Range.ULTRASOUND
            msg.range = float(distance)
            self.ultrasonic_pub.publish(msg)
        
        # 讀取紅外線
        ir_value = self.read_infrared()
        ir_msg = Bool()
        ir_msg.data = ir_value
        self.ir_pub.publish(ir_msg)
    
    def send_to_agent(self, topic_name: str, data: dict):
        """直接發送數據到 micro-ROS Agent (可選)"""
        try:
            payload = json.dumps({
                'topic': topic_name,
                'data': data,
                'timestamp': time.time()
            }).encode('utf-8')
            
            self.socket.sendto(payload, (self.agent_ip, self.agent_port))
        except Exception as e:
            self.get_logger().error(f'Agent 通訊錯誤: {e}')
    
    def destroy_node(self):
        """清理資源"""
        GPIO.cleanup()
        self.socket.close()
        super().destroy_node()

def main(args=None):
    rclpy.init(args=args)
    
    driver = RpiMicroRosDriver()
    
    try:
        rclpy.spin(driver)
    except KeyboardInterrupt:
        pass
    finally:
        driver.destroy_node()
        rclpy.shutdown()

if __name__ == '__main__':
    main()
```

---

## 網路配置與故障排除

### 檢查列表

#### 1. 網路連接驗證

```bash
# A. 檢查 Agent 主機連接
ping 192.168.1.100      # PC 上檢查

# B. 檢查客戶端連接
ping 192.168.1.101      # ESP32 IP
ping 192.168.1.102      # RPi IP

# C. 檢查防火牆
sudo ufw status
sudo ufw allow 8888/udp

# D. 檢查埠占用
sudo ss -ulnp | grep 8888
```

#### 2. Agent 運行狀態診斷

```bash
# A. 檢查 Agent 進程
ps aux | grep micro_ros_agent

# B. 檢查日誌 (systemd)
sudo journalctl -u micro-ros-agent.service -n 50 -f

# C. 檢查 Docker 日誌
docker logs micro_ros_agent

# D. Agent 詳細日誌
MICRO_ROS_AGENT_LOG_LEVEL=debug micro_ros_agent udp4 --port 8888
```

#### 3. 客戶端連接測試

```bash
# 在主機上測試 UDP 連接
# ESP32 連接模擬 (Python)
import socket

client = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
client.sendto(b"test_packet", ("192.168.1.100", 8888))
data, addr = client.recvfrom(1024)
print(f"收到回應: {data}")

# 檢查 ROS 2 節點
ros2 node list
ros2 topic list
ros2 topic echo /sensors/imu/data
```

### 常見問題

| 問題 | 症狀 | 解決方案 |
|------|------|--------|
| **Agent 無法啟動** | 埠已被占用 | `lsof -i :8888` 找出進程並殺止 |
| **客戶端連接失敗** | 同步超時 | 檢查防火牆規則，確認 UDP 8888 開放 |
| **訊息無法接收** | 話題陷入沈寂 | 驗證客戶端發送，檢查序列化格式 |
| **高延遲** | 訊息緩慢 | 切換至 Host 網路模式，檢查 WiFi 品質 |
| **記憶體洩漏** | Agent 佔用不斷增加 | 重啟 Agent，檢查客戶端是否斷開連接 |

### 性能優化建議

```bash
# 1. 調優 UDP 緩衝區
sudo sysctl -w net.core.rmem_max=134217728
sudo sysctl -w net.core.wmem_max=134217728

# 2. 啟用 IP 轉發 (多網段)
sudo sysctl -w net.ipv4.ip_forward=1

# 3. 禁用非必要服務 (Raspberry Pi)
sudo systemctl disable snapd
sudo systemctl disable cups
sudo systemctl disable avahi-daemon

# 4. 設定 CPU Affinity (固定 CPU 核心)
taskset -p -c 0-2 $(pgrep micro_ros_agent)
```

---

## 完整部署工作流

### 推薦部署順序

```
1. ✓ 設定网络 (IP, 防火牆)
   ↓
2. ✓ 在 PC 上啟動 micro-ROS Agent
   ↓
3. ✓ 驗證 Agent 狀態 (ros2 node list)
   ↓
4. ✓ 上傳韌體到 ESP32/RPi
   ↓
5. ✓ 驗證客戶端連接 (檢查日誌)
   ↓
6. ✓ 測試話題發佈 (ros2 topic echo)
   ↓
7. ✓ 整合到 ROS 系統 (啟動其他節點)
```

### 一鍵部署指令

```bash
#!/bin/bash
# deploy_microros.sh

echo "========== micro-ROS 快速部署 =========="

# 1. 網路準備
echo "[1/4] 配置網路..."
ifconfig eth0 192.168.0.100 netmask 255.255.255.0
sudo ufw allow 8888/udp

# 2. 啟動 micro-ROS Agent
echo "[2/4] 啟動 Agent..."
if command -v docker &> /dev/null; then
    docker-compose up -d micro_ros_agent
else
    nohup micro_ros_agent udp4 --port 8888 -v6 > /tmp/agent.log 2>&1 &
fi

# 3. 驗證
echo "[3/4] 驗證連接..."
sleep 2
ros2 node list | grep micro_ros_agent
if [ $? -eq 0 ]; then
    echo "✓ Agent 已成功啟動"
else
    echo "✗ Agent 啟動失敗，詳見日誌"
fi

# 4. 準備就緒
echo "[4/4] 系統準備就緒"
echo "========== 部署完成 =========="
echo ""
echo "後續步驟:"
echo "1. 上傳韌體到 ESP32: Arduino IDE → 上傳"
echo "2. 啟動 Raspberry Pi: ssh pi@192.168.1.102"
echo "3. 驗證話題: ros2 topic list"
```

---

**文檔版本: 1.0**  
**最後更新: 2024年 Q2**  
**推薦部署方案: 開發階段 → Docker, 生產環境 → 主機直接或 Raspberry Pi 整合**
