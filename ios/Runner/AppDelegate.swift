import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {

  private let store = TemplateStore()
  private lazy var router = ASLRouter(store: store)

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "asl_router", binaryMessenger: controller.binaryMessenger)

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }

      switch call.method {

      case "initTemplates":
        guard
          let args = call.arguments as? [String: Any],
          let json = args["templatesJson"] as? String
        else {
          result(FlutterError(code: "BAD_ARGS", message: "Expected { templatesJson: String }", details: nil))
          return
        }

        do {
          try self.store.loadFromJSONString(json)
          print("Templates loaded into Swift: \(self.store.templates.count) intents")
          result(true)
        } catch {
          result(FlutterError(code: "TEMPLATE_LOAD_FAILED", message: "\(error)", details: nil))
        }

      case "routeWords":
        guard
          let args = call.arguments as? [String: Any],
          let words = args["words"] as? [String]
        else {
          result(FlutterError(code: "BAD_ARGS", message: "Expected { words: [String] }", details: nil))
          return
        }

        let sentence = self.router.respond(fromWords: words)
        print("Final sentence (Swift): \(sentence)")
        result(sentence)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}