#!/usr/bin/env python3
"""
Raspberry Pi micro-ROS 感測器驅動 (Python)
感測器: 紅外線 + 超音波 + 距離感測器
通訊: UDP 網路連接 (ROS Agent 埠 8888)
"""

import rclpy
from rclpy.node import Node
from sensor_msgs.msg import Range
from std_msgs.msg import Float32, Bool
import board
import busio
import adafruit_adxl34x
import RPi.GPIO as GPIO
import time
from threading import Thread

class RaspiSensorDriver(Node):
    def __init__(self):
        super().__init__('rpi_sensor_driver')
        
        # GPIO 設定
        self.INFRARED_PIN = 27      # GPIO 27 - 紅外線接收
        self.ULTRASONIC_TRIG = 17   # GPIO 17 - 超音波發射
        self.ULTRASONIC_ECHO = 22   # GPIO 22 - 超音波接收
        
        # 發佈者初始化
        self.infrared_publisher = self.create_publisher(Bool, 'sensors/infrared', 10)
        self.ultrasonic_publisher = self.create_publisher(Range, 'sensors/ultrasonic', 10)
        self.distance_publisher = self.create_publisher(Float32, 'sensors/distance', 10)
        
        # GPIO 模式設定
        GPIO.setmode(GPIO.BCM)
        GPIO.setup(self.INFRARED_PIN, GPIO.IN)
        GPIO.setup(self.ULTRASONIC_TRIG, GPIO.OUT)
        GPIO.setup(self.ULTRASONIC_ECHO, GPIO.IN)
        
        # 初始化 I2C ADXL34x 加速度計 (如需要)
        i2c = busio.I2C(board.SCL, board.SDA)
        self.accel = adafruit_adxl34x.ADXL345(i2c)
        
        # 定期發佈計時器
        self.create_timer(0.05, self.infrared_callback)      # 20 Hz
        self.create_timer(0.1, self.ultrasonic_callback)     # 10 Hz
        self.create_timer(0.5, self.distance_callback)       # 2 Hz
        
        self.get_logger().info('Raspberry Pi 感測器驅動已初始化')
    
    def infrared_callback(self):
        """讀取紅外線感測器"""
        try:
            # 讀取紅外線 (GPIO 高電位表示檢測到物體)
            ir_value = GPIO.input(self.INFRARED_PIN)
            ir_detected = Bool()
            ir_detected.data = bool(ir_value)
            
            self.infrared_publisher.publish(ir_detected)
            
        except Exception as e:
            self.get_logger().error(f'紅外線感測器錯誤: {e}')
    
    def ultrasonic_callback(self):
        """讀取超音波感測器 (HC-SR04)"""
        try:
            # 發送超音波脈衝
            GPIO.output(self.ULTRASONIC_TRIG, False)
            time.sleep(0.000002)  # 2 微秒
            GPIO.output(self.ULTRASONIC_TRIG, True)
            time.sleep(0.00001)   # 10 微秒
            GPIO.output(self.ULTRASONIC_TRIG, False)
            
            # 計時脈衝返回時間
            timeout = time.time()
            while GPIO.input(self.ULTRASONIC_ECHO) == 0:
                timeout = time.time()
                if (time.time() - timeout) > 0.1:
                    return
            
            pulse_start = time.time()
            
            timeout = time.time()
            while GPIO.input(self.ULTRASONIC_ECHO) == 1:
                if (time.time() - timeout) > 0.1:
                    return
            
            pulse_end = time.time()
            
            # 計算距離 (cm)
            pulse_duration = pulse_end - pulse_start
            distance = pulse_duration * 17150.0  # 音速 343 m/s = 17150 cm/s
            
            # ROS Range 消息格式
            range_msg = Range()
            range_msg.header.stamp = self.get_clock().now().to_msg()
            range_msg.header.frame_id = 'ultrasonic_link'
            range_msg.radiation_type = Range.ULTRASOUND
            range_msg.field_of_view = 0.26  # 約 15 度
            range_msg.min_range = 0.02      # 最小範圍 2 cm
            range_msg.max_range = 4.0       # 最大範圍 4 m
            range_msg.range = float(distance / 100.0)  # 轉換為公尺
            
            self.ultrasonic_publisher.publish(range_msg)
            
        except Exception as e:
            self.get_logger().error(f'超音波感測器錯誤: {e}')
    
    def distance_callback(self):
        """讀取距離感測器 (可選 - 例如 VL53L0X)"""
        try:
            # 此處為偽代碼，實際需要根據使用的距離感測器來調整
            # 例如若使用 VL53L0X，則需要導入相應的 I2C 驅動
            
            distance_data = Float32()
            # distance_data.data = self.read_vl53l0x()  # 實際應實現此方法
            distance_data.data = 0.0  # 預設值
            
            self.distance_publisher.publish(distance_data)
            
        except Exception as e:
            self.get_logger().error(f'距離感測器錯誤: {e}')
    
    def destroy_node(self):
        """清理資源"""
        GPIO.cleanup()
        super().destroy_node()


def main(args=None):
    rclpy.init(args=args)
    
    sensor_driver = RaspiSensorDriver()
    
    try:
        rclpy.spin(sensor_driver)
    except KeyboardInterrupt:
        pass
    finally:
        sensor_driver.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
