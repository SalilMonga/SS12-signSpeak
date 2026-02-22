import Foundation
import AVFoundation

// Super small camera streamer just to get CVPixelBuffers.
// We'll feed these buffers into MediaPipe.
final class NativeCameraStream: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

  private let session = AVCaptureSession()
  private let queue = DispatchQueue(label: "native.camera.frames")

  // casual callback: you get a pixelBuffer and a timestamp
  var onFrame: ((CVPixelBuffer, Int) -> Void)?

  func start() {
    session.beginConfiguration()
    session.sessionPreset = .high

    guard
      let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
      let input = try? AVCaptureDeviceInput(device: device),
      session.canAddInput(input)
    else {
      print("NativeCameraStream: failed to set camera input")
      session.commitConfiguration()
      return
    }
    session.addInput(input)

    let output = AVCaptureVideoDataOutput()
    output.videoSettings = [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ]
    output.setSampleBufferDelegate(self, queue: queue)

    guard session.canAddOutput(output) else {
      print("NativeCameraStream: failed to add output")
      session.commitConfiguration()
      return
    }
    session.addOutput(output)

    session.commitConfiguration()
    session.startRunning()
    print("NativeCameraStream: running ✅")
  }

  func stop() {
    session.stopRunning()
  }

  // AVCaptureVideoDataOutputSampleBufferDelegate
  func captureOutput(_ output: AVCaptureOutput,
                     didOutput sampleBuffer: CMSampleBuffer,
                     from connection: AVCaptureConnection) {
    guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    let t = Int(Date().timeIntervalSince1970 * 1000)
    onFrame?(pb, t)
  }
}
