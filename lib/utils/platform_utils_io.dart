import 'dart:io';
import 'dart:ffi' hide Size;
import 'package:win32/win32.dart';
import 'platform_utils.dart';

typedef WndEnumProc = Int32 Function(IntPtr handle, IntPtr lparam);

class IOPlatformUtils implements PlatformUtils {
  @override
  bool get isWindows => Platform.isWindows;
  @override
  bool get isMacOS => Platform.isMacOS;
  @override
  bool get isLinux => Platform.isLinux;
  @override
  bool get isAndroid => Platform.isAndroid;
  @override
  bool get isIOS => Platform.isIOS;
  @override
  bool get isMobile => Platform.isAndroid || Platform.isIOS;
  @override
  bool get isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  @override
  bool get isWeb => false;

  int? _cachedHwnd;

  int _getHwnd() {
    if (_cachedHwnd != null && IsWindow(_cachedHwnd!) != 0) {
      return _cachedHwnd!;
    }
    
    int hwnd = 0;
    
    // 1. Try finding by class name FLUTTER_RUNNER_WIN32_WINDOW
    hwnd = FindWindow(TEXT('FLUTTER_RUNNER_WIN32_WINDOW'), nullptr);
    
    // 2. Try finding by possible window titles (QuantaKeys, QuantaKeys Hub, quantakeys)
    if (hwnd == 0) {
      hwnd = FindWindow(nullptr, TEXT('QuantaKeys'));
    }
    if (hwnd == 0) {
      hwnd = FindWindow(nullptr, TEXT('QuantaKeys Hub'));
    }
    if (hwnd == 0) {
      hwnd = FindWindow(nullptr, TEXT('quantakeys'));
    }
    
    // 3. Absolute Fallback: Get active window
    if (hwnd == 0) {
      hwnd = GetActiveWindow();
    }
    
    _cachedHwnd = hwnd;
    return hwnd;
  }

  @override
  void setWindowNonFocusable(bool nonFocusable) {
    applyWindowSettings(nonFocusable: nonFocusable, alwaysOnTop: true);
  }

  @override
  void applyWindowSettings({required bool nonFocusable, required bool alwaysOnTop}) {
    if (!Platform.isWindows) return;
    
    int hwnd = _getHwnd();
    if (hwnd == 0) return;

    final int currentExStyle = GetWindowLongPtr(hwnd, GWL_EXSTYLE);
    final int currentStyle = GetWindowLongPtr(hwnd, GWL_STYLE);
    
    int newExStyle = currentExStyle;
    int newStyle = currentStyle;

    if (nonFocusable) {
      // WS_EX_NOACTIVATE (0x08000000) prevents taking focus when clicked.
      // WS_EX_TOOLWINDOW (0x00000080) keeps window clean.
      newExStyle |= (WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW);
      // Ensure WS_EX_TRANSPARENT is cleared so mouse events/drags are captured
      newExStyle &= ~WS_EX_TRANSPARENT;
      newStyle &= ~(WS_CAPTION | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU);
      newStyle |= (WS_POPUP | WS_THICKFRAME);
    } else {
      newExStyle &= ~(WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW);
      newStyle |= (WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU);
    }

    if (alwaysOnTop) {
      newExStyle |= WS_EX_TOPMOST;
    } else {
      newExStyle &= ~WS_EX_TOPMOST;
    }
    
    newExStyle &= ~0x00000020; 

    if (currentExStyle != newExStyle || currentStyle != newStyle) {
      SetWindowLongPtr(hwnd, GWL_EXSTYLE, newExStyle);
      SetWindowLongPtr(hwnd, GWL_STYLE, newStyle);
      
      final int zOrder = alwaysOnTop ? HWND_TOPMOST : HWND_NOTOPMOST;
      
      SetWindowPos(hwnd, zOrder, 0, 0, 0, 0, 
          SWP_NOMOVE | SWP_NOSIZE | SWP_FRAMECHANGED | SWP_NOACTIVATE | SWP_NOOWNERZORDER | SWP_NOSENDCHANGING);
    }

    if (nonFocusable) {
      ShowWindow(hwnd, SW_HIDE);
      ShowWindow(hwnd, SW_SHOWNOACTIVATE);
    } else {
      ShowWindow(hwnd, SW_SHOW);
      SetForegroundWindow(hwnd);
      SetActiveWindow(hwnd);
    }
  }
}

PlatformUtils getPlatformUtils() => IOPlatformUtils();
