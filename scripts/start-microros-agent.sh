#!/bin/bash

################################################################################
# micro-ROS Agent 快速啟動指令檔 (本地版本)
# 用途: 快速啟動本地 micro-ROS UDP Agent
################################################################################

# 顏色定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

MICROROS_WS="$HOME/microros_ws"
AGENT_PORT=${1:-8888}

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  micro-ROS Agent UDP 快速啟動               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# 檢查 micro-ROS 工作區
if [ ! -d "$MICROROS_WS/install" ]; then
    echo -e "${RED}✗ micro-ROS 工作區未找到或尚未編譯${NC}"
    echo ""
    echo "請先執行:"
    echo "  bash $HOME/ros2_deployment/scripts/all-in-one-deploy.sh"
    echo ""
    exit 1
fi

# 啟用 ROS 2 環境
echo -e "${BLUE}▸ 啟用 ROS 2 環境...${NC}"
source /opt/ros/humble/setup.bash
source "$MICROROS_WS/install/setup.bash"

echo -e "${GREEN}✓ 環境已啟用${NC}"
echo ""

# 檢查埠是否被占用
echo -e "${BLUE}▸ 檢查 UDP 埠 $AGENT_PORT...${NC}"

if command -v netstat &> /dev/null; then
    if netstat -uln 2>/dev/null | grep -q ":$AGENT_PORT "; then
        echo -e "${YELLOW}⚠ 埠 $AGENT_PORT 已被占用${NC}"
        echo "請選擇其他埠或停止占用該埠的程序"
        exit 1
    fi
elif command -v ss &> /dev/null; then
    if ss -uln 2>/dev/null | grep -q ":$AGENT_PORT "; then
        echo -e "${YELLOW}⚠ 埠 $AGENT_PORT 已被占用${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✓ 埠 $AGENT_PORT 可用${NC}"
echo ""

# 設定 ROS 環境變數
export ROS_DOMAIN_ID=0
export ROS_LOCALHOST_ONLY=0

echo "配置信息:"
echo "  ROS_DOMAIN_ID: $ROS_DOMAIN_ID"
echo "  UDP 埠: $AGENT_PORT"
echo "  工作區: $MICROROS_WS"
echo ""

# 啟動 micro-ROS Agent
echo -e "${BLUE}▸ 啟動 micro-ROS UDP Agent (CTRL+C 停止)...${NC}"
echo ""

# 檢查是否存在 micro_ros_agent 二進制檔
if command -v micro_ros_agent &> /dev/null; then
    echo -e "${GREEN}✓ micro-ROS Agent 已找到${NC}"
    echo ""
    
    # 啟動 Agent
    micro_ros_agent udp4 --port "$AGENT_PORT" -v6
    
elif [ -f "$MICROROS_WS/install/micro_ros_agent/bin/micro_ros_agent" ]; then
    echo -e "${GREEN}✓ micro-ROS Agent 在工作區中${NC}"
    echo ""
    
    # 啟動 Agent
    "$MICROROS_WS/install/micro_ros_agent/bin/micro_ros_agent" udp4 --port "$AGENT_PORT" -v6
else
    echo -e "${RED}✗ 無法找到 micro-ROS Agent 執行檔${NC}"
    echo ""
    echo "請確保已安裝 micro-ROS Agent:"
    echo "  cd $MICROROS_WS"
    echo "  colcon build --symlink-install"
    exit 1
fi
