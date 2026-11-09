import 'input_injector.dart';

class WebInputInjector implements InputInjector {
  @override
  Future<void> injectText(String text) async {
    // Internal only on web
  }

  @override
  void injectArrow(int direction) {}

  @override
  void injectEnter() {}

  @override
  void injectBackspace() {}

  @override
  void injectCopy() {}

  @override
  void injectPaste() {}
}

InputInjector getInputInjector() => WebInputInjector();
