#!/bin/bash

################################################################################
# ROS 2 清潔與重置指令檔
# 用途: 清潔構建產物、緩存與臨時檔案
################################################################################

# 顏色定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

ROS2_WS="$HOME/ros2_ws"
MICROROS_WS="$HOME/microros_ws"

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     ROS 2 清潔與重置工具                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# 解析命令行參數
CLEAN_TYPE="${1:-help}"

case $CLEAN_TYPE in
    build)
        echo -e "${YELLOW}▸ 清潔構建檔案 (build, install)${NC}"
        echo ""
        
        if [ -d "$ROS2_WS" ]; then
            echo "清潔 ROS 2 工作區..."
            cd "$ROS2_WS"
            rm -rf build install
            echo -e "${GREEN}✓ 完成${NC}"
        fi
        
        if [ -d "$MICROROS_WS" ]; then
            echo "清潔 micro-ROS 工作區..."
            cd "$MICROROS_WS"
            rm -rf build install
            echo -e "${GREEN}✓ 完成${NC}"
        fi
        
        echo ""
        echo "後續步驟: 執行 colcon build --symlink-install 重新編譯"
        ;;
    
    cache)
        echo -e "${YELLOW}▸ 清潔 ROS 緩存與日誌${NC}"
        echo ""
        
        # 清潔 ROS daemon
        if [ -d "$HOME/.ros" ]; then
            echo "清潔 ROS daemon..."
            rm -rf "$HOME/.ros"
            echo -e "${GREEN}✓ 完成${NC}"
        fi
        
        # 清潔日誌
        if [ -d "$HOME/.local/share/ros" ]; then
            echo "清潔日誌檔案..."
            rm -rf "$HOME/.local/share/ros"
            echo -e "${GREEN}✓ 完成${NC}"
        fi
        ;;
    
    colcon)
        echo -e "${YELLOW}▸ 清潔 colcon 快取${NC}"
        echo ""
        
        if [ -d "$HOME/.colcon" ]; then
            echo "清潔 colcon 配置..."
            rm -rf "$HOME/.colcon"
            echo -e "${GREEN}✓ 完成${NC}"
        fi
        ;;
    
    all)
        echo -e "${RED}▸ 執行完全清潔 (build, install, cache, colcon)${NC}"
        echo ""
        
        read -p "確認完全清潔? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            $0 build
            $0 cache
            $0 colcon
            
            echo ""
            echo -e "${GREEN}✓ 完全清潔完成${NC}"
        else
            echo "已取消"
        fi
        ;;
    
    help|*)
        echo "清潔選項:"
        echo ""
        echo "  build    清潔構建檔案 (build/, install/)"
        echo "  cache    清潔 ROS 緩存與日誌"
        echo "  colcon   清潔 colcon 快取"
        echo "  all      執行完全清潔"
        echo "  help     顯示此幫助信息"
        echo ""
        echo "使用方式:"
        echo "  bash clean.sh build"
        echo "  bash clean.sh all"
        echo ""
        ;;
esac

echo ""
