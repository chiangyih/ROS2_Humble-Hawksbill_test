#!/bin/bash

################################################################################
# ROS 2 部署驗證與診斷指令檔
# 用途: 驗證所有系統組件是否正確安裝與運行
################################################################################

set -e

# 顏色定義
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ROS2_WS="$HOME/ros2_ws"

# 測試計數器
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNED=0

test_result() {
    local test_name="$1"
    local status="$2"
    local detail="$3"
    
    case $status in
        pass)
            echo -e "${GREEN}[✓]${NC} $test_name"
            ((TESTS_PASSED++))
            ;;
        fail)
            echo -e "${RED}[✗]${NC} $test_name: $detail"
            ((TESTS_FAILED++))
            ;;
        warn)
            echo -e "${YELLOW}[!]${NC} $test_name: $detail"
            ((TESTS_WARNED++))
            ;;
    esac
}

echo "╔════════════════════════════════════════════════════════╗"
echo "║     ROS 2 部署驗證 - 系統診斷報告                     ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# ============ 系統檢查 ============
echo -e "${BLUE}▸ 系統環境檢查${NC}"

# 檢查 OS
if grep -i "ubuntu" /etc/os-release > /dev/null; then
    test_result "Ubuntu 系統" "pass"
else
    test_result "Ubuntu 系統" "fail" "不是 Ubuntu 系統"
fi

# 檢查磁碟空間
available=$(df "$HOME" | awk 'NR==2 {print $4}')
if [ "$available" -gt 5242880 ]; then
    test_result "磁碟空間 ($(($available/1024/1024))GB)" "pass"
else
    test_result "磁碟空間" "fail" "空間不足"
fi

# 檢查 sudo
if sudo -n true 2>/dev/null; then
    test_result "sudo 權限" "pass"
else
    test_result "sudo 權限" "warn" "需要密碼"
fi

echo ""

# ============ ROS 2 安裝檢查 ============
echo -e "${BLUE}▸ ROS 2 Humble 安裝檢查${NC}"

# 檢查 ROS 2 命令
if command -v ros2 &> /dev/null; then
    test_result "ros2 命令" "pass"
    ROS2_VERSION=$(ros2 --version 2>&1 || echo "unknown")
    echo "  版本: $ROS2_VERSION"
else
    test_result "ros2 命令" "fail" "未安裝"
fi

# 檢查 ROS 2 核心套件
if [ -d "/opt/ros/humble" ]; then
    test_result "/opt/ros/humble 目錄" "pass"
else
    test_result "/opt/ros/humble 目錄" "fail" "目錄不存在"
fi

# 檢查環境設定
if grep -q "source /opt/ros/humble/setup.bash" "$HOME/.bashrc" 2>/dev/null; then
    test_result ".bashrc ROS 環境設定" "pass"
else
    test_result ".bashrc ROS 環境設定" "warn" "未在 .bashrc 中配置"
fi

echo ""

# ============ 編譯工具檢查 ============
echo -e "${BLUE}▸ 編譯工具檢查${NC}"

# 檢查 colcon
if command -v colcon &> /dev/null; then
    test_result "colcon 構建工具" "pass"
else
    test_result "colcon 構建工具" "fail" "未安裝"
fi

# 檢查 cmake
if command -v cmake &> /dev/null; then
    CMAKE_VERSION=$(cmake --version | head -1)
    test_result "cmake" "pass"
    echo "  $CMAKE_VERSION"
else
    test_result "cmake" "fail" "未安裝"
fi

# 檢查 git
if command -v git &> /dev/null; then
    test_result "git 版本控制" "pass"
else
    test_result "git 版本控制" "fail" "未安裝"
fi

# 檢查 rosdep
if command -v rosdep &> /dev/null; then
    test_result "rosdep 相依管理" "pass"
else
    test_result "rosdep 相依管理" "fail" "未安裝"
fi

echo ""

# ============ 工作區檢查 ============
echo -e "${BLUE}▸ ROS 2 工作區檢查${NC}"

if [ -d "$ROS2_WS" ]; then
    test_result "工作區目錄存在" "pass"
    echo "  位置: $ROS2_WS"
    
    # 檢查構建目錄
    if [ -d "$ROS2_WS/build" ]; then
        test_result "構建目錄" "pass"
    else
        test_result "構建目錄" "warn" "尚未構建"
    fi
    
    # 檢查安裝目錄
    if [ -d "$ROS2_WS/install" ]; then
        test_result "安裝目錄" "pass"
    else
        test_result "安裝目錄" "warn" "尚未安裝"
    fi
    
    # 檢查原始碼目錄
    if [ -d "$ROS2_WS/src" ]; then
        COUNT=$(find "$ROS2_WS/src" -maxdepth 1 -type d -not -name "." | wc -l)
        test_result "原始碼目錄" "pass"
        echo "  套件數: $COUNT"
    else
        test_result "原始碼目錄" "fail" "不存在"
    fi
else
    test_result "工作區目錄存在" "fail" "工作區未建立"
fi

echo ""

# ============ 網路檢查 ============
echo -e "${BLUE}▸ 網路連接檢查${NC}"

if ping -c 1 8.8.8.8 &> /dev/null; then
    test_result "互聯網連接" "pass"
else
    test_result "互聯網連接" "warn" "無法連接 Google DNS"
fi

# 檢查 DNS
if nslookup github.com &> /dev/null; then
    test_result "DNS 解析" "pass"
else
    test_result "DNS 解析" "warn" "DNS 解析可能有問題"
fi

echo ""

# ============ micro-ROS 檢查 ============
echo -e "${BLUE}▸ micro-ROS 工具檢查${NC}"

MICROROS_WS="$HOME/microros_ws"

if [ -d "$MICROROS_WS" ]; then
    test_result "micro-ROS 工作區" "pass"
    
    if [ -d "$MICROROS_WS/install" ]; then
        test_result "micro-ROS 安裝" "pass"
    else
        test_result "micro-ROS 安裝" "warn" "尚未安裝"
    fi
else
    test_result "micro-ROS 工作區" "warn" "未建立"
fi

echo ""

# ============ 通訊檢查 ============
echo -e "${BLUE}▸ ROS 2 通訊測試${NC}"

# 嘗試列出節點（需要在活躍的 ROS 環境中）
if source /opt/ros/humble/setup.bash 2>/dev/null && timeout 3 ros2 daemon start 2>/dev/null; then
    test_result "ROS 2 daemon" "pass"
    
    if timeout 3 ros2 node list &>/dev/null; then
        test_result "ROS 2 節點通訊" "pass"
    else
        test_result "ROS 2 節點通訊" "warn" "暫時無活躍節點"
    fi
else
    test_result "ROS 2 daemon" "warn" "無法啟動 daemon"
fi

echo ""

# ============ 部署檔案檢查 ============
echo -e "${BLUE}▸ 部署檔案檢查${NC}"

DEPLOY_DIR="$HOME/ros2_deployment"

for file in \
    "docker-compose.yml" \
    "DEPLOYMENT_GUIDE.md" \
    "MICRO_ROS_DEPLOYMENT.md" \
    "DEPLOYMENT_SUCCESS.md" \
    "config/cyclonedds.xml"; do
    
    if [ -f "$DEPLOY_DIR/$file" ]; then
        test_result "文件: $file" "pass"
    else
        test_result "文件: $file" "warn" "未找到"
    fi
done

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║                  驗證結果總結                           ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo -e "  ${GREEN}通過${NC}: $TESTS_PASSED"
echo -e "  ${YELLOW}警告${NC}: $TESTS_WARNED"
echo -e "  ${RED}失敗${NC}: $TESTS_FAILED"
echo ""

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}✓ 系統驗證通過！${NC}"
    echo ""
    echo "後續步驟:"
    echo "  1. 啟用 ROS 環境: source /opt/ros/humble/setup.bash"
    echo "  2. 進入工作區: cd $ROS2_WS"
    echo "  3. 列出節點: ros2 node list"
    exit 0
else
    echo -e "${RED}✗ 存在未解決的問題，請查看上方報告。${NC}"
    exit 1
fi
