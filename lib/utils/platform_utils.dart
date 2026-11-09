import 'platform_utils_stub.dart'
    if (dart.library.io) 'platform_utils_io.dart'
    if (dart.library.js_interop) 'platform_utils_web.dart';

abstract class PlatformUtils {
  bool get isWindows;
  bool get isMacOS;
  bool get isLinux;
  bool get isAndroid;
  bool get isIOS;
  bool get isMobile;
  bool get isDesktop;
  bool get isWeb;

  void setWindowNonFocusable(bool nonFocusable);
  void applyWindowSettings({required bool nonFocusable, required bool alwaysOnTop});
  
  factory PlatformUtils() => getPlatformUtils();
}
