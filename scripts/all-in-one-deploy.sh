#!/bin/bash

################################################################################
# ROS 2 機械手臂視景整合系統 — 一鍵本地部署指令檔
# 環境: WSL2 Ubuntu 22.04 LTS
# 用途: 自動化完整安裝與配置（無需 Docker）
################################################################################

set -e  # 遇到錯誤立即退出

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'  # 無顏色

# 全域變數
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROS2_WS="$HOME/ros2_ws"
DEPLOYMENT_DIR="$HOME/ros2_deployment"
LOG_FILE="$HOME/ros2_deployment.log"

################################################################################
# 工具函式
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1" | tee -a "$LOG_FILE"
}

progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local percent=$((current * 100 / total))
    local completed=$((width * current / total))
    
    printf "\r["
    printf "%${completed}s" | tr ' ' '='
    printf "%$((width - completed))s" | tr ' ' '-'
    printf "] %d%%" "$percent"
}

check_command() {
    if command -v "$1" &> /dev/null; then
        log_success "$1 已安裝"
        return 0
    else
        log_warning "$1 未找到"
        return 1
    fi
}

################################################################################
# 第 1 階段: 系統檢查
################################################################################

phase_system_check() {
    log_info "=== 第 1 階段: 系統環境檢查 ==="
    
    # 檢查發行版本
    log_info "檢查 Linux 發行版..."
    if ! grep -i "ubuntu" /etc/os-release > /dev/null; then
        log_error "本腳本需要 Ubuntu 系統"
        exit 1
    fi
    
    if ! grep -i "22.04" /etc/os-release > /dev/null; then
        log_warning "檢測到非 22.04 版本，但可能相容"
    fi
    
    log_success "Ubuntu 系統驗證通過"
    
    # 檢查網路連接
    log_info "檢查網路連接..."
    if ping -c 1 8.8.8.8 &> /dev/null; then
        log_success "網路連接正常"
    else
        log_warning "無法連接到 8.8.8.8，某些線上資源可能無法下載"
    fi
    
    # 檢查磁碟空間
    log_info "檢查可用磁碟空間..."
    available_space=$(df "$HOME" | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 5242880 ]; then  # 5GB
        log_error "磁碟空間不足 (需要 5GB 以上)"
        exit 1
    fi
    log_success "磁碟空間充足 (可用: $(($available_space / 1024 / 1024))GB)"
    
    # 檢查 sudo 權限
    log_info "檢查 sudo 權限..."
    if sudo -n true 2>/dev/null; then
        log_success "sudo 權限可用"
    else
        log_warning "需要輸入密碼以使用 sudo"
        sudo -v
    fi
}

################################################################################
# 第 2 階段: 基礎系統更新
################################################################################

phase_system_update() {
    log_info "=== 第 2 階段: 系統更新與相依套件安裝 ==="
    
    log_info "更新套件清單..."
    sudo apt-get update -qq
    progress_bar 1 3
    
    log_info "升級已安裝套件..."
    sudo apt-get upgrade -y -qq
    progress_bar 2 3
    
    log_info "安裝基礎相依套件..."
    sudo apt-get install -y -qq \
        build-essential \
        curl \
        git \
        wget \
        make \
        cmake \
        pkg-config \
        python3-pip \
        python3-dev \
        python3-venv \
        lsb-release \
        gnupg \
        ca-certificates \
        apt-transport-https \
        software-properties-common \
        libssl-dev \
        libffi-dev
    
    progress_bar 3 3
    log_success "系統基礎套件安裝完成"
}

################################################################################
# 第 3 階段: ROS 2 Humble 安裝
################################################################################

phase_ros2_install() {
    log_info "=== 第 3 階段: ROS 2 Humble 安裝 ==="
    
    # 檢查是否已安裝
    if check_command "ros2"; then
        log_warning "ROS 2 已安裝，跳過安裝步驟"
        return 0
    fi
    
    log_info "設定 ROS 2 套件庫..."
    
    # 方法 1: 使用官方套件庫 (如果可用)
    if curl -s https://repo.ros.org/ros.key | sudo apt-key add - 2>/dev/null; then
        log_success "ROS 2 GPG 金鑰添加成功"
        sudo add-apt-repository "deb http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" -y
        sudo apt-get update -qq
        
        log_info "安裝 ROS 2 Humble Desktop Full..."
        sudo apt-get install -y -qq ros-humble-desktop
        
        log_success "ROS 2 Humble 安裝完成"
    else
        log_warning "無法使用官方套件庫，嘗試替代方案..."
        
        # 方法 2: 從原始碼編譯 (備選)
        phase_ros2_build_from_source
    fi
}

phase_ros2_build_from_source() {
    log_info "從原始碼編譯 ROS 2 Humble..."
    
    mkdir -p "$ROS2_WS/src"
    cd "$ROS2_WS"
    
    # 安裝必要工具
    log_info "安裝編譯工具..."
    sudo apt-get install -y -qq \
        python3-rosdep \
        python3-rosinstall \
        python3-rosinstall-generator \
        python3-wstool \
        python3-colcon-common-extensions
    
    log_info "初始化 rosdep..."
    sudo rosdep init 2>/dev/null || true
    rosdep update
    
    log_info "複製 ROS 2 源碼 (這可能需要 5-10 分鐘)..."
    if [ ! -d "$ROS2_WS/src/ros2" ]; then
        git clone https://github.com/ros2/ros2.git src/ros2 -b humble 2>&1 | grep -E "Cloning|fatal" || true
    fi
    
    log_info "導入相依套件..."
    cd "$ROS2_WS/src/ros2"
    vcs import < ros2.repos 2>&1 | tail -5
    
    log_info "安裝 ROS 2 相依..."
    cd "$ROS2_WS"
    rosdep install --from-paths src --ignore-src -y --skip-keys "cyclonedds python_cmake_modules" -q
    
    log_info "編譯 ROS 2 (這可能需要 20-30 分鐘，請耐心等待)..."
    colcon build --symlink-install 2>&1 | tee -a "$LOG_FILE" | tail -20
    
    log_success "ROS 2 Humble 從原始碼編譯完成"
}

################################################################################
# 第 4 階段: micro-ROS 工具安裝
################################################################################

phase_microros_install() {
    log_info "=== 第 4 階段: micro-ROS 工具安裝 ==="
    
    log_info "安裝 micro-ROS 相依套件..."
    sudo apt-get install -y -qq \
        python3-vcstool \
        python3-colcon-metadata \
        libopencv-dev
    
    log_info "建立 micro-ROS 工作區..."
    mkdir -p "$HOME/microros_ws/src"
    cd "$HOME/microros_ws"
    
    log_info "複製 micro-ROS 代理..."
    git clone -b humble https://github.com/micro-ROS/micro-ROS-Agent.git src/micro-ROS-Agent -q
    
    log_info "安裝相依..."
    rosdep install --from-paths src --ignore-src -y -q
    
    log_info "編譯 micro-ROS Agent..."
    source /opt/ros/humble/setup.bash || true
    colcon build --symlink-install -q
    
    log_success "micro-ROS 工具安裝完成"
}

################################################################################
# 第 5 階段: 工作區設定
################################################################################

phase_workspace_setup() {
    log_info "=== 第 5 階段: ROS 2 工作區設定 ==="
    
    # 建立工作區
    mkdir -p "$ROS2_WS/src"
    cd "$ROS2_WS/src"
    
    log_info "複製感測器驅動包..."
    
    # 建立感測器驅動包
    if [ ! -d "robot_sensor_fusion" ]; then
        mkdir -p robot_sensor_fusion/src
cat > robot_sensor_fusion/package.xml << 'EOFXML'
<?xml version="1.0"?>
<package format="2">
  <name>robot_sensor_fusion</name>
  <version>0.1.0</version>
  <description>Robot sensor fusion package</description>
  <maintainer email="user@example.com">Robot Team</maintainer>
  <license>Apache-2.0</license>
  
  <buildtool_depend>ament_cmake</buildtool_depend>
  <buildtool_depend>rosidl_default_generators</buildtool_depend>
  
  <depend>rclcpp</depend>
  <depend>sensor_msgs</depend>
  <depend>geometry_msgs</depend>
  <depend>std_msgs</depend>
  
  <exec_depend>rosidl_default_runtime</exec_depend>
</package>
EOFXML
        
cat > robot_sensor_fusion/CMakeLists.txt << 'EOFCMAKE'
cmake_minimum_required(VERSION 3.8)
project(robot_sensor_fusion)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
find_package(sensor_msgs REQUIRED)
find_package(geometry_msgs REQUIRED)
find_package(std_msgs REQUIRED)

include_directories(include)

ament_package()
EOFCMAKE
        
        log_success "感測器驅動包已建立"
    fi
    
    # 編譯工作區
    log_info "編譯 ROS 2 工作區..."
    cd "$ROS2_WS"
    colcon build --symlink-install 2>&1 | tail -5
    
    log_success "工作區編譯完成"
}

################################################################################
# 第 6 階段: 環境配置
################################################################################

phase_environment_config() {
    log_info "=== 第 6 階段: 環境變數配置 ==="
    
    # 檢查並添加到 .bashrc
    if ! grep -q "source /opt/ros/humble/setup.bash" "$HOME/.bashrc"; then
        log_info "添加 ROS 2 環境變數到 .bashrc..."
        cat >> "$HOME/.bashrc" << 'EOF'

# ROS 2 Humble 環境
source /opt/ros/humble/setup.bash
export ROS_DOMAIN_ID=0
export ROS_LOCALHOST_ONLY=0
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
EOF
        log_success "環境變數已添加"
    else
        log_success "環境變數已存在"
    fi
    
    # 建立啟用指令碼
    cat > "$HOME/activate_ros2.sh" << 'EOF'
#!/bin/bash
# 快速啟用 ROS 2 環境

source /opt/ros/humble/setup.bash
export ROS_DOMAIN_ID=0
export ROS_LOCALHOST_ONLY=0
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp

echo "✓ ROS 2 環境已啟用"
bash
EOF
    
    chmod +x "$HOME/activate_ros2.sh"
    log_success "環境配置完成"
}

################################################################################
# 第 7 階段: 系統驗證
################################################################################

phase_verification() {
    log_info "=== 第 7 階段: 系統驗證 ==="
    
    # 啟用環境
    source /opt/ros/humble/setup.bash || true
    
    # 檢查 ROS 2
    log_info "驗證 ROS 2 安裝..."
    if command -v ros2 &> /dev/null; then
        log_success "ROS 2 命令可用"
        ros2 --version 2>&1 | tee -a "$LOG_FILE"
    else
        log_error "ROS 2 命令不可用"
        return 1
    fi
    
    # 檢查 colcon
    log_info "驗證 ColCon..."
    if check_command "colcon"; then
        colcon --version | tee -a "$LOG_FILE"
    fi
    
    # 檢查 rosdep
    log_info "驗證 rosdep..."
    if check_command "rosdep"; then
        log_success "rosdep 可用"
    fi
    
    # 測試工作區
    log_info "測試工作區編譯..."
    cd "$ROS2_WS"
    if [ -d "build" ]; then
        log_success "工作區編譯成功"
    fi
    
    log_success "系統驗證完成"
}

################################################################################
# 第 8 階段: 部署檔案準備
################################################################################

phase_deployment_files() {
    log_info "=== 第 8 階段: 部署檔案準備 ==="
    
    log_info "複製部署配置檔..."
    cp -r "$DEPLOYMENT_DIR/config" "$ROS2_WS/" || true
    cp -r "$DEPLOYMENT_DIR/launch" "$ROS2_WS/" || true
    cp -r "$DEPLOYMENT_DIR/scripts" "$ROS2_WS/" || true
    
    log_success "部署檔案準備完成"
}

################################################################################
# 主函式
################################################################################

main() {
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║   ROS 2 機械手臂視景整合系統 — 一鍵本地部署指令檔        ║"
    echo "║   環境: WSL2 Ubuntu 22.04 LTS                             ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    # 建立日誌檔案
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    
    # 執行各階段
    phase_system_check
    phase_system_update
    phase_ros2_install
    phase_microros_install
    phase_workspace_setup
    phase_environment_config
    phase_verification
    phase_deployment_files
    
    # 最終總結
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                  ✓ 部署完成！                              ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "重要信息:"
    echo "  1. 工作區位置: $ROS2_WS"
    echo "  2. 環境啟用: source $HOME/activate_ros2.sh"
    echo "  3. 或編輯 .bashrc 使環境永久有效"
    echo ""
    echo "驗證安裝:"
    echo "  $ source /opt/ros/humble/setup.bash"
    echo "  $ ros2 node list"
    echo ""
    echo "日誌檔案: $LOG_FILE"
    echo ""
}

# 錯誤處理
trap 'log_error "指令碼執行中斷"; exit 1' INT TERM

# 執行主函式
main "$@"
