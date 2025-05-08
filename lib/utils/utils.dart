import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

class Utils {
  // Generates a unique file name based on the current date and time
  static String generateFileName(DateTime dateTime) {
    final DateFormat formatter = DateFormat('yyyyMMdd_HHmmss');
    return formatter.format(dateTime);
  }

  static Future<bool> checkAndRequestPermissions(
      {required bool skipIfExists}) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return false;
    }

    if (Platform.isAndroid) {
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = deviceInfo.version.sdkInt;
      if (skipIfExists) {
        return sdkInt >= 33
            ? await Permission.photos.request().isGranted
            : await Permission.storage.request().isGranted;
      } else {
        return sdkInt >= 29
            ? true
            : await Permission.storage.request().isGranted;
      }
    } else if (Platform.isIOS) {
      return skipIfExists
          ? await Permission.photos.request().isGranted
          : await Permission.photosAddOnly.request().isGranted;
    }

    return false;
  }
}
