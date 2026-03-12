"""
ROS 2 整合啟動檔案
包含: HIWIN 機械手臂 + 視覺系統 + 感測器集成
"""

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare
import os
from ament_index_python.packages import get_package_share_directory


def generate_launch_description():
    
    # 宣告啟動參數
    robot_ip = DeclareLaunchArgument(
        'robot_ip',
        default_value='192.168.0.1',
        description='HIWIN 機械手臂 IP 位址'
    )
    
    use_fake_hardware = DeclareLaunchArgument(
        'use_fake_hardware',
        default_value='false',
        description='是否使用仿真模式'
    )
    
    camera_device = DeclareLaunchArgument(
        'camera_device',
        default_value='/dev/video0',
        description='攝像頭裝置路徑'
    )
    
    # 1. HIWIN 機械手臂驅動
    hiwin_moveit_launch = IncludeLaunchDescription(
        PythonLaunchDescriptionSource([
            PathJoinSubstitution([
                FindPackageShare('hiwin_ra6_moveit_config'),
                'launch',
                'ra6_moveit.launch.py'
            ])
        ]),
        launch_arguments={
            'ra_type': 'ra605_710',
            'use_fake_hardware': LaunchConfiguration('use_fake_hardware'),
            'robot_ip': LaunchConfiguration('robot_ip'),
        }.items()
    )
    
    # 2. 攝像頭節點 (v4l2_camera)
    camera_node = Node(
        package='v4l2_camera',
        executable='v4l2_camera_node',
        name='camera_node',
        namespace='vision',
        parameters=[{
            'video_device': LaunchConfiguration('camera_device'),
            'frame_id': 'camera_link',
            'pixel_format': 'YUYV',
            'image_width': 640,
            'image_height': 480,
            'camera_frame_id': 'camera_optical_frame',
        }],
        output='screen'
    )
    
    # 3. 靜態坐標轉換發佈器 (Eye-to-Hand 座標)
    # T_camera^base: camera 相對於 robot base_link 的變換
    static_transform_publisher = Node(
        package='tf2_ros',
        executable='static_transform_publisher',
        name='tf_camera_broadcaster',
        arguments=['--x', '0.1',      # X 偏移 (公尺)
                   '--y', '0.05',     # Y 偏移
                   '--z', '0.3',      # Z 偏移 (高度)
                   '--roll', '0',     # Roll (弧度)
                   '--pitch', '-1.57', # Pitch (指向下方)
                   '--yaw', '0',      # Yaw
                   '--frame-id', 'base_link',
                   '--child-frame-id', 'camera_link'],
        output='screen'
    )
    
    # 4. 感測器驅動節點 - ESP32 IMU & 溫溼度
    esp32_sensor_node = Node(
        package='micro_ros_agent',
        executable='micro_ros_agent',
        name='esp32_sensor_driver',
        parameters=[{
            'device_id': 'esp32_imu',
            'namespace': 'sensors/imu',
        }],
        remappings=[
            ('imu/data', '/imu/data'),
            ('temp_humidity', '/sensors/temp_humidity'),
        ],
        output='screen'
    )
    
    # 5. Raspberry Pi 感測器驅動
    # (紅外線、超音波、距離感測器)
    rpi_sensor_node = Node(
        package='micro_ros_agent',
        executable='micro_ros_agent',
        name='rpi_sensor_driver',
        parameters=[{
            'device_id': 'raspberry_pi',
            'namespace': 'sensors/infrared',
        }],
        remappings=[
            ('infrared', '/sensors/infrared'),
            ('ultrasonic', '/sensors/ultrasonic'),
            ('distance', '/sensors/distance'),
        ],
        output='screen'
    )
    
    # 6. 感測器融合與數據聚合節點 (自定義)
    sensor_fusion_node = Node(
        package='robot_sensor_fusion',
        executable='sensor_fusion_node',
        name='sensor_fusion',
        parameters=[{
            'publish_rate': 10.0,  # 無即時性需求，10 Hz 足夠
            'enable_imu': True,
            'enable_temperature': True,
            'enable_infrared': True,
            'enable_ultrasonic': True,
            'enable_distance': True,
        }],
        remappings=[
            ('fused_sensors', '/sensors/fused_data'),
        ],
        output='screen'
    )
    
    # 7. 視覺標定與目標檢測節點 (自定義)
    vision_processing_node = Node(
        package='robot_vision_processing',
        executable='vision_processor_node',
        name='vision_processor',
        parameters=[{
            'detection_model': 'yolov8n',  # 或其他檢測模型
            'confidence_threshold': 0.5,
            'publish_rate': 5.0,
        }],
        remappings=[
            ('image_raw', '/vision/camera/image_raw'),
            ('detection_results', '/vision/detections'),
            ('target_pose', '/vision/target_pose_camera'),
        ],
        output='screen'
    )
    
    # 8. 姿態座標變換節點 (Camera 座標 -> Base 座標)
    pose_transform_node = Node(
        package='robot_vision_processing',
        executable='pose_transformer_node',
        name='pose_transformer',
        parameters=[{
            'source_frame': 'camera_link',
            'target_frame': 'base_link',
            'timeout': 1.0,
        }],
        remappings=[
            ('camera_pose_in', '/vision/target_pose_camera'),
            ('base_pose_out', '/vision/target_pose_base'),
        ],
        output='screen'
    )
    
    # 9. 監測與診斷節點
    diagnostics_node = Node(
        package='diagnostic_aggregator',
        executable='aggregator_node',
        name='diagnostics',
        parameters=[
            os.path.join(get_package_share_directory('robot_diagnostics'),
                        'config', 'diagnostics.yaml')
        ],
        output='screen'
    )
    
    # 10. RViz2 可視化 (選擇性)
    rviz_launch = IncludeLaunchDescription(
        PythonLaunchDescriptionSource([
            PathJoinSubstitution([
                FindPackageShare('hiwin_ra6_moveit_config'),
                'launch',
                'rviz.launch.py'
            ])
        ]),
        launch_arguments={
            'rviz_config': PathJoinSubstitution([
                FindPackageShare('robot_bringup'),
                'config',
                'robot_system.rviz'
            ]),
        }.items()
    )
    
    # 建構啟動描述
    ld = LaunchDescription()
    
    # 添加啟動參數
    ld.add_action(robot_ip)
    ld.add_action(use_fake_hardware)
    ld.add_action(camera_device)
    
    # 添加核心元件 (依照優先順序)
    ld.add_action(hiwin_moveit_launch)      # 機械手臂驅動
    ld.add_action(static_transform_publisher)  # 座標系基礎
    ld.add_action(camera_node)              # 攝像頭
    
    # 添加感測器驅動
    ld.add_action(esp32_sensor_node)
    ld.add_action(rpi_sensor_node)
    
    # 添加融合與處理節點
    ld.add_action(sensor_fusion_node)
    ld.add_action(vision_processing_node)
    ld.add_action(pose_transform_node)
    
    # 添加監測
    ld.add_action(diagnostics_node)
    
    # 可選: 添加 RViz2
    ld.add_action(rviz_launch)
    
    return ld
