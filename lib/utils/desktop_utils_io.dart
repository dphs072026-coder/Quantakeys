import 'dart:io';
import 'package:win32/win32.dart';
import 'desktop_utils.dart';

class IODesktopUtils implements DesktopUtils {
  @override
  void setWindowNonFocusable(bool nonFocusable) {
    if (!Platform.isWindows) return;
    
    // Try to find the window handle of the Flutter window robustly
    int hwnd = FindWindow(TEXT('FLUTTER_RUNNER_WIN32_WINDOW'), TEXT('QuantaKeys'));
    if (hwnd == 0) {
      hwnd = GetActiveWindow();
    }

    if (hwnd != 0) {
      final int exStyle = GetWindowLongPtr(hwnd, GWL_EXSTYLE);
      if (nonFocusable) {
        // WS_EX_NOACTIVATE: Window does not become foreground window when clicked.
        // Explicitly clear WS_EX_TRANSPARENT to ensure hit tests are captured.
        SetWindowLongPtr(hwnd, GWL_EXSTYLE, (exStyle | WS_EX_NOACTIVATE | WS_EX_TOPMOST) & ~WS_EX_TRANSPARENT);
      } else {
        SetWindowLongPtr(hwnd, GWL_EXSTYLE, exStyle & ~WS_EX_NOACTIVATE);
      }
      
      // Force the OS to recognize the flag change and update the window stack
      SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_FRAMECHANGED | SWP_NOACTIVATE);
    }
  }
}

DesktopUtils getDesktopUtils() => IODesktopUtils();
