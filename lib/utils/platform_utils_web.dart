import 'platform_utils.dart';

class WebPlatformUtils implements PlatformUtils {
  @override
  bool get isWindows => false;
  @override
  bool get isMacOS => false;
  @override
  bool get isLinux => false;
  @override
  bool get isAndroid => false;
  @override
  bool get isIOS => false;
  @override
  bool get isMobile => false;
  @override
  bool get isDesktop => false;
  @override
  bool get isWeb => true;

  @override
  void setWindowNonFocusable(bool nonFocusable) {}

  @override
  void applyWindowSettings({required bool nonFocusable, required bool alwaysOnTop}) {}
}

PlatformUtils getPlatformUtils() => WebPlatformUtils();
