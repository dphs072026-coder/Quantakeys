import 'desktop_utils_stub.dart'
    if (dart.library.io) 'desktop_utils_io.dart'
    if (dart.library.js_interop) 'desktop_utils_web.dart';

abstract class DesktopUtils {
  void setWindowNonFocusable(bool nonFocusable);
  
  factory DesktopUtils() => getDesktopUtils();
}
