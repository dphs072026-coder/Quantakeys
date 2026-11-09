import 'desktop_utils.dart';

class WebDesktopUtils implements DesktopUtils {
  @override
  void setWindowNonFocusable(bool nonFocusable) {
    // No-op on web
  }
}

DesktopUtils getDesktopUtils() => WebDesktopUtils();
