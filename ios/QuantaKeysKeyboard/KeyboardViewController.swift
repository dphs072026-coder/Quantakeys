import UIKit
import Flutter

class KeyboardViewController: UIInputViewController {

    var flutterEngine: FlutterEngine?
    var channel: FlutterMethodChannel?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize Flutter Engine for the keyboard
        flutterEngine = FlutterEngine(name: "quanta_engine")
        flutterEngine?.run()

        let flutterViewController = FlutterViewController(engine: flutterEngine!, nibName: nil, bundle: nil)

        // Add Flutter view to the keyboard view controller
        addChild(flutterViewController)
        view.addSubview(flutterViewController.view)
        flutterViewController.view.frame = view.bounds
        flutterViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        flutterViewController.didMove(toParent: self)

        // Setup MethodChannel to communicate with Flutter
        channel = FlutterMethodChannel(name: "com.quantakeys/ime", binaryMessenger: flutterViewController.binaryMessenger)

        channel?.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { return }

            switch call.method {
            case "commitText":
                if let args = call.arguments as? [String: Any],
                   let text = args["text"] as? String {
                    self.textDocumentProxy.insertText(text)
                    result(nil)
                }
            case "deleteText":
                let length = (call.arguments as? [String: Any])?["length"] as? Int ?? 1
                for _ in 0..<length {
                    self.textDocumentProxy.deleteBackward()
                }
                result(nil)
            case "sendAction":
                self.textDocumentProxy.insertText("\n")
                result(nil)
            case "moveCursor":
                let direction = (call.arguments as? [String: Any])?["direction"] as? Int ?? 0
                self.textDocumentProxy.adjustTextPosition(byCharacterOffset: direction)
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        let textBefore = textDocumentProxy.documentContextBeforeInput ?? ""
        channel?.invokeMethod("updateContext", arguments: ["textBefore": textBefore])
    }
}
