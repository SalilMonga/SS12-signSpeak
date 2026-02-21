import Foundation
import AVFoundation
import CoreML
import MediaPipeTasksVision

// Handles: loading the .task model + running hand landmarks on a frame
final class HandLandmarkerService: NSObject {

  private var landmarker: HandLandmarker?
  // tiny wrapper around your CoreML model
  private var modelRunner: TemporalHandNetRunner?

  // one-off test: call this with any pixelBuffer to see if MediaPipe returns landmarks
  func debugProcessOnce(pixelBuffer: CVPixelBuffer) {
    let t = Int(Date().timeIntervalSince1970 * 1000)
    process(pixelBuffer: pixelBuffer, timestampMs: t)
  }

  // Call this once on app start (or when user opens camera screen)
  func start() {
    guard let modelPath = Bundle.main.path(forResource: "hand_landmarker", ofType: "task") else {
      print("hand_landmarker.task not found in app bundle")
      return
    }

    do {
      let options = HandLandmarkerOptions()
      options.baseOptions.modelAssetPath = modelPath

      // live stream mode = meant for camera frames
      options.runningMode = .liveStream

      // tweak later if you want more hands
      options.numHands = 2

      // callback gets results async per frame
      options.handLandmarkerLiveStreamDelegate = self

      landmarker = try HandLandmarker(options: options)
      print("HandLandmarker ready ✅")
    } catch {
      print("Failed to create HandLandmarker:", error)
    }

    // init the TemporalHandNet runner (optional; it's fine if this fails)
    modelRunner = TemporalHandNetRunner()
    if modelRunner == nil {
      print("Warning: TemporalHandNetRunner failed to initialize (model class?)")
    }
  }

  /// Call this for each camera frame you want processed
  func process(pixelBuffer: CVPixelBuffer, timestampMs: Int) {
    guard let landmarker else { return }

    do {
      let mpImage = try MPImage(pixelBuffer: pixelBuffer)
      // async result comes back in the delegate below
      try landmarker.detectAsync(image: mpImage, timestampInMilliseconds: timestampMs)
    } catch {
      print("detectAsync failed:", error)
    }
  }

  // Takes ONE hand's landmarks and makes a 126-length feature vector.
  // For now: [x,y,z] * 21 = 63 floats, then pad to 126 with zeros.
  private func features126(from oneHand: [NormalizedLandmark]) -> [Float] {
    var feats: [Float] = []
    feats.reserveCapacity(126)

    for lm in oneHand {
      feats.append(Float(lm.x))
      feats.append(Float(lm.y))
      feats.append(Float(lm.z))
    }

    // pad to 126 (temporary)
    while feats.count < 126 {
      feats.append(0)
    }

    return feats
  }

  // Convert [Float] -> MLMultiArray(1,16,126). We'll flatten and put the 126 values
  // in the first position (slice 0). The rest stays zero. Adjust later if your model
  // expects a different layout.
  private func makeModelInput(from feats: [Float]) -> MLMultiArray? {
    do {
      // shape matches earlier: [1, 16, 126]
      let arr = try MLMultiArray(shape: [1, 16, 126], dataType: .float32)

      // zero-init to be safe
      for i in 0..<arr.count {
        arr[i] = 0
      }

      // put our 126 floats into the first 126 elements
      // (coreml uses contiguous storage; arr[i] index access is fine)
      let setCount = min(feats.count, arr.count)
      for i in 0..<setCount {
        arr[i] = NSNumber(value: feats[i])
      }
      return arr
    } catch {
      print("Failed to create MLMultiArray:", error)
      return nil
    }
  }
}

// MARK: - Delegate callback (results come back here)
extension HandLandmarkerService: HandLandmarkerLiveStreamDelegate {
  func handLandmarker(
    _ handLandmarker: HandLandmarker,
    didFinishDetection result: HandLandmarkerResult?,
    timestampInMilliseconds: Int,
    error: Error?
  ) {
    if let error {
      print("HandLandmarker error:", error)
      return
    }
    guard let result else { return }

    // Print how many hands we saw (nice quick check)
    print("hands:", result.landmarks.count, "t=", timestampInMilliseconds)

    // use the first detected hand for now
    guard let firstHand = result.landmarks.first else { return }

    // build 126 features
    let f = features126(from: firstHand)

    // quick debug print
    print("feat[0..2] =", f.prefix(3))

    // run model prediction off the main thread (avoid blocking)
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      guard let input = self.makeModelInput(from: f) else { return }
      guard let runner = self.modelRunner else { return }

      if let scores = runner.predict(scoresInput: input) {
        // example output — adapt to your model's semantics later
        // print raw scores
        print("Prediction -> raw scores:", scores)

        // if you have id2label mapping, map argmax -> string and print confidence
        if let bestIndex = scores.enumerated().max(by: { $0.element < $1.element })?.offset {
          let bestScore = scores[bestIndex]
          // If you have a label map, translate index->label name here
          print("Prediction -> index \(bestIndex) | confidence: \(bestScore)")
        }
      } else {
        print("Model prediction failed")
      }
    }
  }
}
