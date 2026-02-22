import Flutter
import UIKit
import CoreVideo

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  private let handService = HandLandmarkerService()
  private var channel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Let Flutter finish booting first
    let ok = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    // Start MediaPipe once app launches
    handService.start()

    return ok
  }

  // helper: copy BGRA bytes into a CVPixelBuffer
  private static func makeBGRAPixelBuffer(
    width: Int,
    height: Int,
    bytesPerRow: Int,
    data: Data
  ) -> CVPixelBuffer? {

    var pb: CVPixelBuffer?
    let attrs: [CFString: Any] = [
      kCVPixelBufferCGImageCompatibilityKey: true,
      kCVPixelBufferCGBitmapContextCompatibilityKey: true
    ]

    let status = CVPixelBufferCreate(
      kCFAllocatorDefault,
      width,
      height,
      kCVPixelFormatType_32BGRA,
      attrs as CFDictionary,
      &pb
    )
    guard status == kCVReturnSuccess, let pixelBuffer = pb else { return nil }

    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

    guard let dstBase = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
    let dstBytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

    data.withUnsafeBytes { srcRaw in
      guard let srcBase = srcRaw.baseAddress else { return }
      for row in 0..<height {
        let srcRow = srcBase.advanced(by: row * bytesPerRow)
        let dstRow = dstBase.advanced(by: row * dstBytesPerRow)
        memcpy(dstRow, srcRow, min(bytesPerRow, dstBytesPerRow))
      }
    }

    return pixelBuffer
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "mediapipe_hands") else {
      print("mediapipe_hands: registrar was nil (channel not registered)")
      return
    }

    let ch = FlutterMethodChannel(name: "mediapipe_hands", binaryMessenger: registrar.messenger())
    self.channel = ch
      
      // iOS -> Flutter: push the latest label up to Dart
      handService.onWord = { [weak self] word in
        DispatchQueue.main.async {
          self?.channel?.invokeMethod("onWord", arguments: ["word": word])
        }
      }

      // iOS -> Flutter: push completed phrase to Dart
      handService.onPhraseComplete = { [weak self] words in
        DispatchQueue.main.async {
          self?.channel?.invokeMethod("onPhraseComplete", arguments: ["words": words])
        }
      }

    ch.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self else { return }

      switch call.method {
      case "processFrameBGRA":
        guard
          let args = call.arguments as? [String: Any],
          let w = args["w"] as? Int,
          let h = args["h"] as? Int,
          let t = args["t"] as? Int,
          let bytesPerRow = args["bytesPerRow"] as? Int,
          let bytes = args["bytes"] as? FlutterStandardTypedData
        else {
          result(FlutterError(code: "BAD_ARGS", message: "Missing frame args", details: nil))
          return
        }

        if let pb = AppDelegate.makeBGRAPixelBuffer(
          width: w,
          height: h,
          bytesPerRow: bytesPerRow,
          data: bytes.data
        ) {
          self.handService.process(pixelBuffer: pb, timestampMs: t)
        }

        result(nil)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
