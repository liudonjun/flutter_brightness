import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/lux_data.dart';

/// 数据库服务类
///
/// 使用SharedPreferences存储和管理校准点数据。
/// 替代了原来的SQLite实现，避免了Windows平台的兼容性问题。
///
/// 主要功能：
/// - 校准点的增删改查操作
/// - 自动去重（相近LUX值的校准点）
/// - 数据统计和分析
/// - 数据导入导出（JSON格式）
/// - 自动排序和优化
///
/// 数据存储格式：
/// 使用JSON字符串存储校准点数组，每个校准点包含：
/// - luxValue: 光照值
/// - brightnessValue: 对应的亮度值
/// - timestamp: 创建时间戳
///
/// 使用示例：
/// ```dart
/// // 添加校准点
/// await DatabaseService.insertCalibrationPoint(point);
///
/// // 获取所有校准点
/// List<CalibrationPoint> points = await DatabaseService.getAllCalibrationPoints();
///
/// // 清除所有数据
/// await DatabaseService.clearAllCalibrationPoints();
/// ```
class DatabaseService {
  static const String _calibrationPointsKey = 'calibration_points';

  static Future<SharedPreferences> get _prefs async {
    return await SharedPreferences.getInstance();
  }

  static Future<void> insertCalibrationPoint(CalibrationPoint point) async {
    final prefs = await _prefs;
    final points = await getAllCalibrationPoints();

    // Remove any existing point with similar lux value (within tolerance)
    points.removeWhere((p) => (p.luxValue - point.luxValue).abs() < 10);

    // Add the new point
    points.add(point);

    // Sort by lux value
    points.sort((a, b) => a.luxValue.compareTo(b.luxValue));

    // Save back to preferences
    final pointsJson = points.map((p) => p.toMap()).toList();
    await prefs.setString(_calibrationPointsKey, json.encode(pointsJson));
  }

  static Future<void> insertCalibrationPoints(List<CalibrationPoint> points) async {
    final prefs = await _prefs;

    // Sort by lux value
    points.sort((a, b) => a.luxValue.compareTo(b.luxValue));

    // Save to preferences
    final pointsJson = points.map((p) => p.toMap()).toList();
    await prefs.setString(_calibrationPointsKey, json.encode(pointsJson));
  }

  static Future<List<CalibrationPoint>> getAllCalibrationPoints() async {
    final prefs = await _prefs;
    final pointsString = prefs.getString(_calibrationPointsKey);

    if (pointsString == null || pointsString.isEmpty) {
      return [];
    }

    try {
      final pointsJson = json.decode(pointsString) as List;
      return pointsJson.map((json) => CalibrationPoint.fromMap(json)).toList();
    } catch (e) {
      // If there's an error parsing, return empty list
      return [];
    }
  }

  static Future<List<CalibrationPoint>> getCalibrationPointsInRange(
    int minLux,
    int maxLux,
  ) async {
    final allPoints = await getAllCalibrationPoints();
    return allPoints
        .where((point) => point.luxValue >= minLux && point.luxValue <= maxLux)
        .toList();
  }

  static Future<void> deleteCalibrationPoint(int luxValue, {int tolerance = 10}) async {
    final prefs = await _prefs;
    final points = await getAllCalibrationPoints();

    // Remove points within tolerance
    points.removeWhere((point) =>
        point.luxValue >= luxValue - tolerance &&
        point.luxValue <= luxValue + tolerance);

    // Save back to preferences
    final pointsJson = points.map((p) => p.toMap()).toList();
    await prefs.setString(_calibrationPointsKey, json.encode(pointsJson));
  }

  static Future<void> clearAllCalibrationPoints() async {
    final prefs = await _prefs;
    await prefs.remove(_calibrationPointsKey);
  }

  static Future<int> getCalibrationPointCount() async {
    final points = await getAllCalibrationPoints();
    return points.length;
  }

  static Future<Map<String, dynamic>> getCalibrationStats() async {
    final points = await getAllCalibrationPoints();

    if (points.isEmpty) {
      return {
        'count': 0,
        'luxRange': [0, 0],
        'brightnessRange': [0, 0],
        'avgBrightness': 0.0,
      };
    }

    final luxValues = points.map((p) => p.luxValue).toList();
    final brightnessValues = points.map((p) => p.brightnessValue).toList();

    final minLux = luxValues.reduce((a, b) => a < b ? a : b);
    final maxLux = luxValues.reduce((a, b) => a > b ? a : b);
    final minBrightness = brightnessValues.reduce((a, b) => a < b ? a : b);
    final maxBrightness = brightnessValues.reduce((a, b) => a > b ? a : b);
    final avgBrightness = brightnessValues.reduce((a, b) => a + b) / brightnessValues.length;

    return {
      'count': points.length,
      'luxRange': [minLux, maxLux],
      'brightnessRange': [minBrightness, maxBrightness],
      'avgBrightness': avgBrightness,
    };
  }

  static Future<void> removeOldCalibrationPoints(DateTime cutoffDate) async {
    final prefs = await _prefs;
    final points = await getAllCalibrationPoints();

    // Remove points older than cutoff date
    points.removeWhere((point) => point.timestamp.isBefore(cutoffDate));

    // Save back to preferences
    final pointsJson = points.map((p) => p.toMap()).toList();
    await prefs.setString(_calibrationPointsKey, json.encode(pointsJson));
  }

  static Future<void> optimizeDatabase() async {
    // For SharedPreferences, this is a no-op as there's no database to optimize
    // But we can sort the calibration points for consistency
    final points = await getAllCalibrationPoints();
    if (points.isNotEmpty) {
      points.sort((a, b) => a.luxValue.compareTo(b.luxValue));
      await insertCalibrationPoints(points);
    }
  }

  static Future<void> closeDatabase() async {
    // For SharedPreferences, this is a no-op as there's no database connection to close
  }
}