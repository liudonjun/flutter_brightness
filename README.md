### 核心组件

- **SerialService**：串口通信服务，负责与光照度传感器设备通信
- **BrightnessService**：Windows 系统亮度控制服务
- **DatabaseService**：本地数据存储服务，管理校准数据
- **AutostartService**：开机自启动管理服务
- **BrightnessMapping**：亮度映射算法，计算最佳亮度值

### 数据模型

- **LuxData**：光照度数据模型，存储传感器读取的光照值
- **CalibrationPoint**：校准点数据模型，存储光照度与亮度的对应关系

### 环境要求

- Flutter SDK >= 3.4.4
- Dart SDK >= 3.0.0
- Windows 操作系统（使用了 Windows API）
- 光照度传感器设备（支持串口通信）

### 安装依赖

```bash
flutter pub get
```

### 运行应用

```bash
flutter run
```

### 构建发布版本

```bash
flutter build windows
```

## 依赖包

| 依赖包                | 版本   | 用途             |
| --------------------- | ------ | ---------------- |
| flutter_libserialport | ^0.4.0 | 串口通信         |
| shared_preferences    | ^2.2.2 | 本地数据存储     |
| ffi                   | ^2.1.0 | Windows FFI 调用 |
| win32                 | ^5.0.9 | Windows API 访问 |
| window_manager        | ^0.3.7 | 窗口管理         |

## 项目结构

```
lib/
├── main.dart                           # 应用入口
├── models/
│   └── lux_data.dart                   # 数据模型
├── screens/
│   └── brightness_control_screen.dart  # 主界面
├── services/
│   ├── serial_service.dart             # 串口通信服务
│   ├── brightness_service.dart         # 亮度控制服务
│   ├── database_service.dart           # 数据库服务
│   └── autostart_service.dart          # 自启动服务
└── utils/
    └── brightness_mapping.dart         # 亮度映射算法
```
