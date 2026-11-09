import 'input_injector_stub.dart'
    if (dart.library.io) 'input_injector_io.dart'
    if (dart.library.js_interop) 'input_injector_web.dart';

abstract class InputInjector {
  Future<void> injectText(String text);
  void injectArrow(int direction);
  void injectEnter();
  void injectBackspace();
  void injectCopy();
  void injectPaste();
  
  factory InputInjector() => getInputInjector();
}
