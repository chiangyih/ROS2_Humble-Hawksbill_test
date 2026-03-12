/*
 * ESP32 micro-ROS 感測器驅動 (Arduino C++)
 * 感測器: IMU (MPU6050) + 溫溼度 (DHT22)
 * 通訊: UDP 網路連接 (ROS Agent 埠 8888)
 */

#include <micro_ros_arduino.h>
#include <stdio.h>
#include <unistd.h>
#include <rcl/rcl.h>
#include <rcl/error_handling.h>
#include <rclc/rclc.h>
#include <rclc/executor.h>
#include <sensor_msgs/msg/imu.h>
#include <std_msgs/msg/float32_multi_array.h>
#include <std_msgs/msg/float32.h>

// MPU6050 I2C 地址
#define MPU6050_ADDR 0x68
#define DHT21_PIN 23  // GPIO 23

// ROS 變量
rcl_publisher_t imu_publisher;
rcl_publisher_t temp_humidity_publisher;
rcl_publisher_t distance_publisher;
sensor_msgs__msg__Imu imu_msg;
std_msgs__msg__Float32MultiArray temp_humidity_msg;
std_msgs__msg__Float32 distance_msg;
rclc_executor_t executor;
rcl_allocator_t allocator;
rcl_node_t node;
rcl_support_t support;

// WiFi 配置
const char * ssid = "your_ssid";
const char * password = "your_password";
const char * agent_ip = "192.168.1.100";  // ROS Agent 主機 IP
const uint16_t agent_port = 8888;

// 初始化 MPU6050
bool init_mpu6050() {
  // I2C 初始化 (SDA=21, SCL=22)
  Wire.begin(21, 22);
  delay(10);
  
  // 檢查 MPU6050 連接
  Wire.beginTransmission(MPU6050_ADDR);
  if (Wire.endTransmission() != 0) {
    return false;  // 連接失敗
  }
  
  // 喚醒 MPU6050
  Wire.beginTransmission(MPU6050_ADDR);
  Wire.write(0x6B);  // PWR_MGMT_1
  Wire.write(0x00);
  Wire.endTransmission();
  
  delay(10);
  return true;
}

// 從 MPU6050 讀取 IMU 數據
void read_mpu6050() {
  Wire.beginTransmission(MPU6050_ADDR);
  Wire.write(0x3B);  // ACCEL_XOUT_H
  Wire.endTransmission();
  Wire.requestFrom(MPU6050_ADDR, 14);
  
  int16_t accel_x = Wire.read() << 8 | Wire.read();
  int16_t accel_y = Wire.read() << 8 | Wire.read();
  int16_t accel_z = Wire.read() << 8 | Wire.read();
  int16_t temp = Wire.read() << 8 | Wire.read();
  int16_t gyro_x = Wire.read() << 8 | Wire.read();
  int16_t gyro_y = Wire.read() << 8 | Wire.read();
  int16_t gyro_z = Wire.read() << 8 | Wire.read();
  
  // 轉換為物理單位
  imu_msg.linear_acceleration.x = (accel_x / 16384.0) * 9.81;
  imu_msg.linear_acceleration.y = (accel_y / 16384.0) * 9.81;
  imu_msg.linear_acceleration.z = (accel_z / 16384.0) * 9.81;
  
  imu_msg.angular_velocity.x = (gyro_x / 131.0) * 0.0174533;  // 轉換為 rad/s
  imu_msg.angular_velocity.y = (gyro_y / 131.0) * 0.0174533;
  imu_msg.angular_velocity.z = (gyro_z / 131.0) * 0.0174533;
  
  // 時間戳
  imu_msg.header.stamp.sec = esp_timer_get_time() / 1000000;
  imu_msg.header.stamp.nanosec = (esp_timer_get_time() % 1000000) * 1000;
  imu_msg.header.frame_id.capacity = 20;
  imu_msg.header.frame_id.size = 12;
  strcpy((char*)imu_msg.header.frame_id.data, "imu_link");
}

// 讀取温度和濕度 (DHT22)
void read_dht22() {
  // 簡化的DHT22讀取 (需要額外的DHT22函式庫)
  // 此處為偽代碼，實際需要使用 Adafruit_DHT 或類似函式庫
  
  float humidity = 0.0;
  float temperature = 0.0;
  
  // 使用 DHT 函式庫讀取
  // read_dht22_data(DHT21_PIN, &humidity, &temperature);
  
  // 組裝訊息
  temp_humidity_msg.data.data[0] = temperature;     // 索引 0 - 溫度
  temp_humidity_msg.data.data[1] = humidity;        // 索引 1 - 濕度
  temp_humidity_msg.data.size = 2;
}

// 讀取距離感測器 (類比或 GPIO)
void read_distance_sensor() {
  int analog_value = analogRead(32);  // GPIO 32 - 類比輸入
  float distance_cm = analog_value * 0.1953;  // 轉換為厘米 (簡化)
  distance_msg.data = distance_cm;
}

// 定期發布 IMU 數據
void timer_callback_imu(rcl_timer_t * timer, int64_t last_call_time) {
  read_mpu6050();
  rcl_publish(&imu_publisher, &imu_msg, NULL);
}

// 定期發布温度/濕度
void timer_callback_temp_humidity(rcl_timer_t * timer, int64_t last_call_time) {
  read_dht22();
  rcl_publish(&temp_humidity_publisher, &temp_humidity_msg, NULL);
}

// 定期發布距離
void timer_callback_distance(rcl_timer_t * timer, int64_t last_call_time) {
  read_distance_sensor();
  rcl_publish(&distance_publisher, &distance_msg, NULL);
}

void setup() {
  Serial.begin(115200);
  set_microros_transports();
  
  delay(2000);
  
  // 初始化 WiFi
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi 已連接");
    Serial.print("IP: ");
    Serial.println(WiFi.localIP());
  }
  
  // 初始化感測器
  if (!init_mpu6050()) {
    Serial.println("MPU6050 初始化失敗");
    while(1);
  }
  
  // micro-ROS 初始化
  allocator = rcl_get_default_allocator();
  
  rclc_support_init(&support, 0, NULL, &allocator);
  rclc_node_init_default(&node, "esp32_sensor_node", NULL, &support);
  
  // 建立發佈者
  rclc_publisher_init_default(
    &imu_publisher,
    &node,
    ROSIDL_GET_MSG_TYPE_SUPPORT(sensor_msgs, msg, Imu),
    "sensors/imu/data");
  
  rclc_publisher_init_default(
    &temp_humidity_publisher,
    &node,
    ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, Float32MultiArray),
    "sensors/temp_humidity");
  
  rclc_publisher_init_default(
    &distance_publisher,
    &node,
    ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, Float32),
    "sensors/distance");
  
  // 初始化定期器
  rcl_timer_t imu_timer;
  rclc_timer_init_default2(&imu_timer, &support, RCL_MS_TO_NS(50), timer_callback_imu);  // 20 Hz
  
  rcl_timer_t temp_timer;
  rclc_timer_init_default2(&temp_timer, &support, RCL_MS_TO_NS(1000), timer_callback_temp_humidity);  // 1 Hz
  
  rcl_timer_t distance_timer;
  rclc_timer_init_default2(&distance_timer, &support, RCL_MS_TO_NS(500), timer_callback_distance);  // 2 Hz
  
  rclc_executor_init(&executor, &support.context, 3, &allocator);
  rclc_executor_add_timer(&executor, &imu_timer);
  rclc_executor_add_timer(&executor, &temp_timer);
  rclc_executor_add_timer(&executor, &distance_timer);
}

void loop() {
  rclc_executor_spin_some(&executor, RCL_MS_TO_NS(10));
  delay(10);
}
