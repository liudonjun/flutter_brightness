import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Windows开机自启动服务类
///
/// 提供Windows系统开机自启动功能的管理。
/// 通过修改Windows注册表来实现应用程序的自动启动。
///
/// 功能特性：
/// - 启用/禁用开机自启动
/// - 检查当前自启动状态
/// - 安全的注册表操作（仅修改当前用户）
/// - 自动错误处理和日志记录
///
/// 注册表位置：
/// HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
///
/// 安全说明：
/// - 只修改当前用户的注册表，不需要管理员权限
/// - 自动处理注册表操作错误
/// - 使用安全的内存管理（自动释放分配的内存）
///
/// 使用示例：
/// ```dart
/// // 检查自启动状态
/// bool enabled = AutoStartService.isAutoStartEnabled();
///
/// // 启用自启动
/// bool success = AutoStartService.enableAutoStart();
///
/// // 禁用自启动
/// bool success = AutoStartService.disableAutoStart();
///
/// // 切换自启动状态
/// bool success = AutoStartService.toggleAutoStart();
/// ```
class AutoStartService {
  static const String _appName = 'FlutterBrightness';
  static const String _registryPath = r'SOFTWARE\Microsoft\Windows\CurrentVersion\Run';

  /// 检查应用是否已设置为开机自启动
  static bool isAutoStartEnabled() {
    try {
      final keyHandle = calloc<IntPtr>();
      final result = RegOpenKeyEx(
        HKEY_CURRENT_USER,
        _registryPath.toNativeUtf16(),
        0,
        KEY_READ,
        keyHandle,
      );

      if (result != ERROR_SUCCESS) {
        calloc.free(keyHandle);
        return false;
      }

      final valueNamePtr = _appName.toNativeUtf16();
      final dataSize = calloc<DWORD>();
      dataSize.value = 0;

      // 先获取数据大小
      final queryResult = RegQueryValueEx(
        keyHandle.value,
        valueNamePtr,
        nullptr,
        nullptr,
        nullptr,
        dataSize,
      );

      RegCloseKey(keyHandle.value);
      calloc.free(keyHandle);
      calloc.free(valueNamePtr);
      calloc.free(dataSize);

      return queryResult == ERROR_SUCCESS;
    } catch (e) {
      print('检查自启动状态失败: $e');
      return false;
    }
  }

  /// 启用开机自启动
  static bool enableAutoStart() {
    try {
      final executablePath = Platform.resolvedExecutable;

      final keyHandle = calloc<IntPtr>();
      final result = RegOpenKeyEx(
        HKEY_CURRENT_USER,
        _registryPath.toNativeUtf16(),
        0,
        KEY_WRITE,
        keyHandle,
      );

      if (result != ERROR_SUCCESS) {
        print('无法打开注册表键');
        calloc.free(keyHandle);
        return false;
      }

      final valueNamePtr = _appName.toNativeUtf16();
      final valueDataPtr = executablePath.toNativeUtf16();

      final setResult = RegSetValueEx(
        keyHandle.value,
        valueNamePtr,
        0,
        REG_SZ,
        valueDataPtr.cast<Uint8>(),
        (executablePath.length + 1) * 2, // UTF-16 字符串长度
      );

      RegCloseKey(keyHandle.value);
      calloc.free(keyHandle);
      calloc.free(valueNamePtr);
      calloc.free(valueDataPtr);

      if (setResult == ERROR_SUCCESS) {
        print('自启动已启用: $executablePath');
        return true;
      } else {
        print('设置自启动失败，错误代码: $setResult');
        return false;
      }
    } catch (e) {
      print('启用自启动失败: $e');
      return false;
    }
  }

  /// 禁用开机自启动
  static bool disableAutoStart() {
    try {
      final keyHandle = calloc<IntPtr>();
      final result = RegOpenKeyEx(
        HKEY_CURRENT_USER,
        _registryPath.toNativeUtf16(),
        0,
        KEY_WRITE,
        keyHandle,
      );

      if (result != ERROR_SUCCESS) {
        print('无法打开注册表键');
        calloc.free(keyHandle);
        return false;
      }

      final valueNamePtr = _appName.toNativeUtf16();
      final deleteResult = RegDeleteValue(keyHandle.value, valueNamePtr);

      RegCloseKey(keyHandle.value);
      calloc.free(keyHandle);
      calloc.free(valueNamePtr);

      if (deleteResult == ERROR_SUCCESS) {
        print('自启动已禁用');
        return true;
      } else if (deleteResult == ERROR_FILE_NOT_FOUND) {
        print('自启动项不存在，无需删除');
        return true;
      } else {
        print('禁用自启动失败，错误代码: $deleteResult');
        return false;
      }
    } catch (e) {
      print('禁用自启动失败: $e');
      return false;
    }
  }

  /// 切换自启动状态
  static bool toggleAutoStart() {
    if (isAutoStartEnabled()) {
      return disableAutoStart();
    } else {
      return enableAutoStart();
    }
  }

  /// 获取当前可执行文件路径
  static String getExecutablePath() {
    return Platform.resolvedExecutable;
  }
}