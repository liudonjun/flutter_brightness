/// 光照度数据模型类
/// 用于存储从传感器读取的光照度值和时间戳
class LuxData {
  /// 光照度值（单位：勒克斯）
  final int luxValue;
  /// 数据采集时间戳
  final DateTime timestamp;

  LuxData({
    required this.luxValue,
    required this.timestamp,
  });

  /// 从串口数据解析光照度信息
  /// 解析格式：LUX:数值
  /// 例如：LUX:500 表示 500 勒克斯
  factory LuxData.fromSerial(String serialData) {
    final match = RegExp(r'LUX:(\d+)').firstMatch(serialData);
    if (match != null) {
      final luxValue = int.parse(match.group(1)!);
      return LuxData(
        luxValue: luxValue,
        timestamp: DateTime.now(),
      );
    }
    throw FormatException('Invalid serial data format: $serialData');
  }

  @override
  String toString() {
    return 'LuxData{luxValue: $luxValue, timestamp: $timestamp}';
  }
}

/// 校准点数据模型类
/// 用于存储亮度校准过程中的光照度与屏幕亮度对应关系
class CalibrationPoint {
  /// 环境光照度值（单位：勒克斯）
  final int luxValue;
  /// 对应的屏幕亮度值（0-255）
  final int brightnessValue;
  /// 校准数据记录时间
  final DateTime timestamp;

  CalibrationPoint({
    required this.luxValue,
    required this.brightnessValue,
    required this.timestamp,
  });

  /// 将校准点数据转换为 Map，用于数据库存储
  Map<String, dynamic> toMap() {
    return {
      'lux_value': luxValue,
      'brightness_value': brightnessValue,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  /// 从 Map 数据创建校准点对象，用于数据库读取
  factory CalibrationPoint.fromMap(Map<String, dynamic> map) {
    return CalibrationPoint(
      luxValue: map['lux_value'],
      brightnessValue: map['brightness_value'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
    );
  }
}