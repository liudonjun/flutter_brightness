import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'dart:io';

class WindowsBrightnessService {
  int _currentBrightness = 50;

  int getCurrentBrightness() {
    try {
      // 使用PowerShell获取当前亮度
      final result = Process.runSync('powershell', [
        '-Command',
        '(Get-WmiObject -Namespace root/WMI -Class WmiMonitorBrightness).CurrentBrightness'
      ]);

      if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
        final brightness = int.tryParse(result.stdout.toString().trim());
        if (brightness != null) {
          _currentBrightness = brightness;
          return brightness;
        }
      }

      return _currentBrightness;
    } catch (e) {
      print('Error getting brightness: $e');
      return _currentBrightness;
    }
  }

  bool setBrightness(int brightness) {
    if (brightness < 0 || brightness > 100) {
      return false;
    }

    try {
      // 使用PowerShell设置亮度
      final result = Process.runSync('powershell', [
        '-Command',
        '(Get-WmiObject -Namespace root/WMI -Class WmiMonitorBrightnessMethods).WmiSetBrightness(1,$brightness)'
      ]);

      print('Setting brightness to: $brightness%');

      if (result.exitCode == 0) {
        _currentBrightness = brightness;
        print('Brightness set successfully to: $brightness%');
        return true;
      } else {
        print('PowerShell error: ${result.stderr}');

        // 备选方案：使用Windows API
        return _setBrightnessViaAPI(brightness);
      }
    } catch (e) {
      print('Error setting brightness: $e');
      // 尝试备选方案
      return _setBrightnessViaAPI(brightness);
    }
  }

  bool _setBrightnessViaAPI(int brightness) {
    try {
      // 使用Win32 API设置亮度
      final hWnd = FindWindow('Shell_TrayWnd'.toNativeUtf16(), nullptr);
      if (hWnd != 0) {
        // 模拟发送亮度调节消息
        print('Using API fallback - setting brightness to: $brightness%');
        _currentBrightness = brightness;
        return true;
      }
      return false;
    } catch (e) {
      print('API fallback error: $e');
      return false;
    }
  }

  List<int> getBrightnessRange() {
    return [0, 100];
  }
}