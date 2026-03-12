# ROS 2 機械手臂視景整合系統 - 自動部署指南

## 📋 目錄

1. [系統需求與環境準備](#系統需求與環境準備)
2. [網路配置](#網路配置)
3. [第一階段：基礎框架部署](#第一階段基礎框架部署)
4. [第二階段：硬體通訊整合](#第二階段硬體通訊整合)
5. [第三階段：視景與座標同步](#第三階段視景與座標同步)
6. [第四階段：系統整合測試](#第四階段系統整合測試)
7. [故障排除](#故障排除)
8. [性能優化](#性能優化)

---

## 系統需求與環境準備

### 硬體清單

| 元件 | 規格說明 | 數量 | 備註 |
|------|--------|------|------|
| **主機 (PC/Server)** | Ubuntu 22.04 LTS, 4 GB RAM 以上 | 1 | Docker 容器執行機 |
| **HIWIN 機械手臂** | RA605-710 或相容型號 | 1 | TCP/IP 控制 |
| **網路攝像頭** | USB 或 IP CAM, 1080p 30fps | 1 | Eye-to-Hand 設定 |
| **ESP32** | ESP32-WROOM-32 或更高 | 1 | IMU + 溫溼度感測 |
| **Raspberry Pi** | RPi 4B 或 RPi 5, 4 GB RAM | 1 | 紅外線、超音波、距離感測 |
| **網路交換機** | 有線區段 (Gigabit 推薦) | 1 | PC ↔ HIWIN 連接 |
| **WiFi 路由器** | 2.4GHz / 5GHz, 802.11n 以上 | 1 | ESP32 ↔ RPi 連接 |

### 軟體需求

```bash
# 主機環境
- Ubuntu 22.04 LTS
- ROS 2 Humble Desktop Full
- Docker Engine 20.10+
- Docker Compose 1.29+
- Python 3.10+
- Git

# 微控制器韌體
- Arduino IDE 2.0+ (ESP32 編程)
- Arduino 核心: esp32 2.0.0+
- Python 3.8+ (Raspberry Pi)
```

### 初始化與安裝

```bash
# 1. 建立工作區結構
mkdir -p ~/ros2_deployment/{launch,config,firmware,scripts,docker}
cd ~/ros2_deployment

# 2. 安裝 ROS 2 Humble 和依賴
sudo apt update && sudo apt upgrade -y
curl -sSL https://raw.githubusercontent.com/ros/ros/master/ros.asc | sudo apt-key add -
sudo apt-add-repository "deb http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main"
sudo apt install ros-humble-desktop-full -y

# 3. 安裝 Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
newgrp docker

# 4. 安裝 Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 5. 建立 ROS 工作區
mkdir -p ~/ros2_ws/src
cd ~/ros2_ws
```

---

## 網路配置

### 網路拓樸圖

```
[WiFi 路由器]
    |
    +---- [ESP32] (192.168.1.x)
    |
    +---- [Raspberry Pi] (192.168.1.y)
    |
    +---- [PC - WiFi 介面] (192.168.1.z)
    |
[有線交換機] ---- [PC - 有線介面] (192.168.0.a)
    |
    +---- [HIWIN 控制箱] (192.168.0.1)
```

### IP 地址分配

| 設備 | 網段 | IP 地址 | 子網掩碼 | 閘道 |
|------|------|--------|---------|------|
| HIWIN 控制箱 | 有線 | 192.168.0.1 | 255.255.255.0 | 192.168.0.254 |
| PC (有線) | 有線 | 192.168.0.100 | 255.255.255.0 | 192.168.0.254 |
| PC (WiFi) | WiFi | 192.168.1.100 | 255.255.255.0 | 192.168.1.1 |
| ESP32 | WiFi | 192.168.1.101 | 255.255.255.0 | 192.168.1.1 |
| Raspberry Pi | WiFi | 192.168.1.102 | 255.255.255.0 | 192.168.1.1 |

### 配置步驟

#### A. PC 有線網卡配置

```bash
# 編輯 Netplan 配置
sudo nano /etc/netplan/01-netcfg.yaml

# 輸入以下內容
network:
  version: 2
  ethernets:
    enp2s0:  # 有線網卡名稱，執行 ip addr 確認
      dhcp4: false
      addresses:
        - 192.168.0.100/24
      gateway4: 192.168.0.254
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]

# 應用設定
sudo netplan apply

# 驗證
ip addr show
```

#### B. PC WiFi 網卡配置

```bash
# 連接到 WiFi （使用 nmcli）
nmcli dev wifi list
nmcli dev wifi connect "your_ssid" password "your_password"

# 驗證連接
nmcli connection show
```

#### C. ROS DDS (Cyclone DDS) 配置

```bash
# 建立 Cyclone DDS 配置檔
cat > /etc/cyclonedds.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8" ?>
<CycloneDDS xmlns="https://cdds.io/config" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="https://cdds.io/config https://raw.githubusercontent.com/eclipse-cyclonedds/cyclonedds/master/etc/cyclonedds.xsd">
  <Domain Id="0">
    <General>
      <NetworkInterfaceAddress>192.168.1.100</NetworkInterfaceAddress>
      <AllowMulticast>true</AllowMulticast>
    </General>
    <Discovery>
      <Tag>$HOSTNAME</Tag>
    </Discovery>
  </Domain>
</CycloneDDS>
EOF

# 驗證設定
export CYCLONEDDS_URI=file:///etc/cyclonedds.xml
ros2 daemon stop
ros2 daemon start
```

---

## 第一階段：基礎框架部署

### 步驟 1.1: 建立 ROS 工作區

```bash
cd ~/ros2_ws/src

# 複製 HIWIN ROS 2 驅動
git clone https://github.com/HIWINCorporation/hiwin_ros2.git

# 複製 MoveIt 2 配置
git clone https://github.com/moveit/moveit2.git

# 複製其他相依套件
git clone https://github.com/ros/cv_bridge.git
git clone https://github.com/ros-perception/image_common.git
git clone https://github.com/ros-perception/vision_opencv.git

# 返回工作區
cd ~/ros2_ws

# 安裝相依套件
rosdep install --from-paths src/ --ignore-src -y

# 編譯工作區
colcon build --symlink-install

# 驗證編譯
source install/setup.bash
ros2 pkg list | grep hiwin
```

### 步驟 1.2: Docker 環境準備

```bash
# 複製 docker-compose.yml 到 ~/ros2_deployment/
cp docker-compose.yml ~/ros2_deployment/

# 構建 Docker 映像 (可選，如需自定義)
docker build -t ros2-humble-with-hiwin:latest .

# 設置環境變數
echo 'export ROBOT_IP=192.168.0.1' >> ~/.bashrc
source ~/.bashrc

# 驗證 Docker 安裝
docker ps
docker-compose --version
```

### 步驟 1.3: 啟動基礎容器組合

```bash
cd ~/ros2_deployment

# 啟動 ROS Core 和 micro-ROS Agent
docker-compose up -d ros2_core micro_ros_agent

# 檢查容器狀態
docker-compose ps

# 查看日誌
docker-compose logs -f ros2_core
docker-compose logs -f micro_ros_agent

# 驗證 ROS 連通性
docker exec ros2_core ros2 node list
docker exec micro_ros_agent ros2 node list
```

---

## 第二階段：硬體通訊整合

### 步驟 2.1: HIWIN 機械手臂驅動配置

```bash
# 編輯 launch 檔案參數
nano ~/ros2_deployment/launch/robot_system.launch.py

# 確認以下參數：
# - robot_ip: 192.168.0.1  (修改為實際 IP)
# - ra_type: ra605_710      (根據機械手臂型號)
# - use_fake_hardware: false (實機模式)

# 啟動 HIWIN 驅動 (測試用)
docker exec -it hiwin_driver bash -c "
  source install/setup.bash
  ros2 launch hiwin_ra6_moveit_config ra6_moveit.launch.py \
    robot_ip:=192.168.0.1 \
    use_fake_hardware:=false
"

# 驗證通訊
ros2 topic list | grep joint
ros2 topic echo /joint_states
```

### 步驟 2.2: ESP32 感測器驅動部署

```bash
# A. 編譯 ESP32 韌體
# 1. 開啟 Arduino IDE
# 2. 開啟 Files > Examples > micro_ros_arduino > micro_ros_arduino_publisher

# 3. 修改以下設定
#    - ssid: your_wifi_ssid
#    - password: your_wifi_password
#    - agent_ip: 192.168.1.100

# 4. 選擇開發板: Tools > Board > esp32 > ESP32 Dev Module
# 5. 編譯上傳

# B. 驗證 ESP32 連接
docker exec micro_ros_agent ros2 node list | grep esp32
docker exec micro_ros_agent ros2 topic list | grep imu

# C. 查看 IMU 數據
docker exec ros2_core bash -c "
  source install/setup.bash
  ros2 topic echo /sensors/imu/data | head -20
"
```

### 步驟 2.3: Raspberry Pi 感測器驅動部署

```bash
# A. SSH 連接到 Raspberry Pi
ssh pi@192.168.1.102

# B. 安裝相依套件
sudo apt update
sudo apt install python3-pip python3-venv git -y
pip3 install RPi.GPIO Adafruit_CircuitPython_ADXL34x adafruit-circuitpython-busdevice

# C. 複製驅動程式
git clone git@github.com:your_user/ros2_deployment.git
cd ros2_deployment/scripts

# D. 權限設定 (GPIO 存取)
sudo usermod -aG gpio $USER
sudo usermod -aG i2c $USER
newgrp gpio

# E. 啟動驅動
ROS_DOMAIN_ID=0 \
RMW_IMPLEMENTATION=rmw_cyclonedds_cpp \
ros2 run robot_sensor_fusion rpi_sensor_driver

# F. 驗證感測器
# (在 PC 上)
docker exec ros2_core bash -c "
  source install/setup.bash
  ros2 topic list | grep sensors
"
```

---

## 第三階段：視景與座標同步

### 步驟 3.1: 攝像頭校準與座標變換

```bash
# A. 攝像頭內參校準 (Camera Intrinsics)
# 使用棋盤標定法獲取相機內參矩陣 K

# 安裝校準工具
sudo apt install ros-humble-camera-calibration-parsers -y

# 執行校準
docker exec -it vision_node bash -c "
  source install/setup.bash
  ros2 run camera_calibration cameracalibrator \
    --size 8x6 --square 0.025 \
    image:=/vision/camera/image_raw \
    camera:=/vision/camera
"

# 儲存校準檔案
# ~/.ros/camera_info/head_camera.yaml

# B. 手眼座標變換標定 (Eye-to-Hand Calibration)
# 使用 easy_handeye 或 aruco_ros 進行標定

git clone https://github.com/IFL-CAMP/easy_handeye.git
cd ~/ros2_ws/src/easy_handeye
colcon build --symlink-install

# 執行手眼標定 (詳細步驟見 easy_handeye 文檔)
ros2 launch easy_handeye calibrate.launch \
  eye_on_hand:=false  # Eye-to-Hand 設置
```

### 步驟 3.2: tf2 靜態座標變換配置

```bash
# 編輯 robot_system.launch.py 中的座標變換參數

# 根據標定結果修改：
# --x 0.1      # X 偏移
# --y 0.05     # Y 偏移
# --z 0.3      # Z 偏移
# --roll 0     # Roll 旋轉
# --pitch -1.57 # Pitch 旋轉
# --yaw 0      # Yaw 旋轉

# 驗證座標變換樹
docker exec ros2_core bash -c "
  source install/setup.bash
  ros2 run tf2_tools view_frames
  evince /tmp/frames.pdf
"
```

### 步驟 3.3: 視覺檢測與目標映射

```bash
# 建立視覺檢測節點 (自定義)
# 路徑: robot_vision_processing/vision_processor_node.py

cat > robot_vision_processing/vision_processor_node.py << 'EOF'
#!/usr/bin/env python3
import rclpy
from rclpy.node import Node
from sensor_msgs.msg import Image
from geometry_msgs.msg import PoseStamped
import cv2
from cv_bridge import CvBridge
import numpy as np

class VisionProcessorNode(Node):
    def __init__(self):
        super().__init__('vision_processor')
        
        # 訂閱攝像頭影像
        self.image_sub = self.create_subscription(
            Image, '/vision/camera/image_raw', self.image_callback, 10)
        
        # 發佈目標姿態 (相機座標系)
        self.target_pose_pub = self.create_publisher(
            PoseStamped, '/vision/target_pose_camera', 10)
        
        self.bridge = CvBridge()
        self.get_logger().info('視覺檢測節點已啟動')
    
    def image_callback(self, msg):
        """處理攝像頭影像"""
        try:
            # 轉換為 OpenCV 格式
            frame = self.bridge.imgmsg_to_cv2(msg, 'bgr8')
            
            # 顏色空間轉換
            hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
            
            # 設定顏色範圍 (例：紅色物體)
            lower_red = np.array([0, 100, 100])
            upper_red = np.array([10, 255, 255])
            
            # 創建遮罩
            mask = cv2.inRange(hsv, lower_red, upper_red)
            
            # 輪廓檢測
            contours, _ = cv2.findContours(
                mask, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
            
            if contours:
                # 找最大輪廓
                largest_contour = max(contours, key=cv2.contourArea)
                
                # 計算中心
                M = cv2.moments(largest_contour)
                if M['m00'] > 0:
                    cx = int(M['m10'] / M['m00'])
                    cy = int(M['m01'] / M['m00'])
                    
                    # 發佈目標位置 (相機座標)
                    target_pose = PoseStamped()
                    target_pose.header.stamp = self.get_clock().now().to_msg()
                    target_pose.header.frame_id = 'camera_link'
                    
                    # 像素座標轉換為 3D 座標
                    target_pose.pose.position.x = (cx - 320) * 0.001  # 簡化轉換
                    target_pose.pose.position.y = (cy - 240) * 0.001
                    target_pose.pose.position.z = 1.0  # 假設深度 1m
                    
                    self.target_pose_pub.publish(target_pose)
        
        except Exception as e:
            self.get_logger().error(f'影像處理錯誤: {e}')

def main(args=None):
    rclpy.init(args=args)
    processor = VisionProcessorNode()
    rclpy.spin(processor)
    rclpy.shutdown()

if __name__ == '__main__':
    main()
EOF

# 編譯並執行
colcon build
ros2 run robot_vision_processing vision_processor_node
```

---

## 第四階段：系統整合測試

### 步驟 4.1: 完整系統啟動

```bash
cd ~/ros2_deployment

# 啟動所有容器
docker-compose up -d

# 檢查所有服務
docker-compose ps

# 驗證所有節點
docker exec ros2_core bash -c "
  source install/setup.bash
  ros2 node list
"

# 驗證所有話題
docker exec ros2_core bash -c "
  source install/setup.bash
  ros2 topic list
"
```

### 步驟 4.2: 性能測試

```bash
# A. 話題延遲測試
docker exec ros2_core bash -c "
  source install/setup.bash
  ros2 run tf2_tools static_transform_publisher \
  --x 0.1 --y 0.05 --z 0.3 \
  --frame-id base_link --child-frame-id camera_link &
  
  ros2 topic list --verbose
"

# B. 訊息頻率測試
docker exec ros2_core bash -c "
  source install/setup.bash
  ros2 topic hz /sensors/imu/data
  ros2 topic hz /joint_states
"

# C. 記錄數據 (rosbag)
docker exec ros2_core bash -c "
  source install/setup.bash
  mkdir -p /tmp/rosbags
  ros2 bag record -o /tmp/rosbags/system_test \
    /sensors/imu/data \
    /sensors/temp_humidity \
    /sensors/infrared \
    /joint_states \
    /vision/camera/image_raw
"
```

### 步驟 4.3: 機械手臂運動驗證

```bash
# 仿真模式測試 (無機械手臂時)
docker-compose down
docker-compose -f docker-compose.yml up -d --build ros2_core

# 編輯 docker-compose.yml，使用 use_fake_hardware:=true
# 並執行 launch 檔案

# 發送目標姿態 (MoveIt)
docker exec ros2_core bash -c "
  source install/setup.bash
  ros2 launch hiwin_ra6_moveit_config demo.launch.py
"

# 在 RViz 中設定目標位置並執行運動規劃
```

---

## 故障排除

### 常見問題與解決方案

| 問題 | 症狀 | 解決方案 |
|------|------|--------|
| **WiFi 連接不穩** | ESP32/RPi 頻繁斷線 | 1. 檢查 WiFi 訊號強度<br>2. 設定固定 WiFi 頻道<br>3. 增加韌體重連機制 |
| **ROS DDS 發現失敗** | 節點間無法通訊 | 1. 確認 CYCLONEDDS_URI<br>2. 檢查防火牆設定 (埠 11311)<br>3. 查看 cyclonedds.xml 網路設定 |
| **攝像頭不識別** | /dev/video0 不存在 | 1. `ls -la /dev/video*` 檢查<br>2. `sudo usermod -aG video $USER`<br>3. 重新插入 USB 攝像頭 |
| **座標變換不正確** | 控制不準確 | 1. 重新執行手眼標定<br>2. 驗證 tf 樹: `ros2 run tf2_tools view_frames`<br>3. 檢查攝像頭內參 |
| **Docker 容器無法啟動** | Exit code 1 | 1. `docker logs <container_name>`<br>2. 檢查卷掛載路徑<br>3. 驗證環境變數設定 |

### 除錯命令

```bash
# 檢查一般系統狀態
ros2 health

# 檢查 ROS 節點樹
ros2 daemon stop && ros2 daemon start
ros2 node list

# 監視特定話題
ros2 topic echo /joint_states --only-n=3

# 檢查話題類型與結構
ros2 topic type /sensors/imu/data
ros2 interface show sensor_msgs/msg/Imu

# 測試機械手臂連接
telnet 192.168.0.1 7000

# Docker 內除錯
docker exec -it ros2_core /bin/bash
# 在容器內執行 ROS 命令
```

---

## 性能優化

### 建議的優化策略

1. **DDS QoS 設定**
   ```bash
   # 控制話題 → Reliable
   # 感測話題 → Best-effort
   # 視覺話題 → Reliable + Large Message
   ```

2. **CPU 資源管理**
   ```bash
   # Docker 限制 CPU 使用
   docker-compose.yml 中添加:
   services:
     hiwin_driver:
       deploy:
         resources:
           limits:
             cpus: '1.5'
             memory: 1G
   ```

3. **網路優化**
   - 使用有線連接 (PC ↔ HIWIN)
   - WiFi 採用 5GHz 頻段
   - 減少不必要的話題發佈

4. **軟體優化**
   - 使用 `--symlink-install` 加速開發迭代
   - 啟用 LTO (Link-Time Optimization)
   - 定期清理 Docker 映像和卷

```bash
# Docker 清理命令
docker system prune -a --volumes
docker image prune -a
```

---

## 快速指令參考

```bash
# 啟動完整系統
cd ~/ros2_deployment && docker-compose up -d

# 停止系統
docker-compose down

# 檢視日誌
docker-compose logs -f ros2_core
docker-compose logs -f hiwin_driver

# 進入容器
docker exec -it ros2_core bash

# 驗證連接
docker exec ros2_core ros2 topic list
docker exec ros2_core ros2 node list

# 錄製數據
ros2 bag record -a -o ~/bags/system_recording

# 回放數據
ros2 bag play ~/bags/system_recording
```

---

**文檔版本: 1.0**  
**最後更新: 2024年 Q2**  
**維護者: Robot Automation Team**
