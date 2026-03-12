#!/bin/bash

################################################################################
# ROS 2 快速啟動指令檔
# 用途: 簡化 ROS 2 環境啟動，方便開發與測試
################################################################################

# 顏色定義
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

ROS2_WS="$HOME/ros2_ws"

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     ROS 2 快速啟動環境                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# 設定 ROS 環境
export ROS_DOMAIN_ID=0
export ROS_LOCALHOST_ONLY=0
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp

# 啟用 ROS 2
if [ -f "/opt/ros/humble/setup.bash" ]; then
    source /opt/ros/humble/setup.bash
    echo -e "${GREEN}✓${NC} ROS 2 Humble 環境已啟用"
else
    echo "✗ ROS 2 Humble 未找到"
    exit 1
fi

# 啟用工作區
if [ -d "$ROS2_WS" ] && [ -f "$ROS2_WS/install/setup.bash" ]; then
    source "$ROS2_WS/install/setup.bash"
    echo -e "${GREEN}✓${NC} ROS 2 工作區已加載 ($ROS2_WS)"
else
    echo "⚠  工作區尚未編譯，請先執行:"
    echo "   cd $ROS2_WS && colcon build --symlink-install"
fi

# 啟用 micro-ROS (如果存在)
MICROROS_WS="$HOME/microros_ws"
if [ -d "$MICROROS_WS" ] && [ -f "$MICROROS_WS/install/setup.bash" ]; then
    source "$MICROROS_WS/install/setup.bash"
    echo -e "${GREEN}✓${NC} micro-ROS 環境已啟用"
fi

echo ""
echo "環境變數:"
echo "  ROS_DOMAIN_ID=$ROS_DOMAIN_ID"
echo "  ROS_LOCALHOST_ONLY=$ROS_LOCALHOST_ONLY"
echo "  RMW_IMPLEMENTATION=$RMW_IMPLEMENTATION"
echo ""

echo "常用命令:"
echo "  ros2 --version          # 查看 ROS 版本"
echo "  ros2 node list          # 列出活躍節點"
echo "  ros2 topic list         # 列出話題"
echo "  ros2 service list       # 列出服務"
echo "  colcon build --symlink-install  # 編譯工作區"
echo ""

# 啟動交互式 shell
echo -e "${GREEN}✓ 您可以開始使用 ROS 2 了！${NC}"
echo ""
bash
