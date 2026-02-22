import Foundation
import AVFoundation
import CoreML
import MediaPipeTasksVision

// Handles: loading the .task model + running hand landmarks on a frame
// Now adds: wrist-relative 126-vector + 16-frame ring buffer, JSON payload prep, CoreML run,
// id2label mapping, and numerically-stable softmax for probability output.
final class HandLandmarkerService: NSObject {

  private var landmarker: HandLandmarker?

  // ring buffer for last 16 frames (each frame -> [Float] length 126)
  private var frameBuffer: [[Float]] = []
  private let bufferSize = 16
  private let bufferQueue = DispatchQueue(label: "hand.buffer.queue")

  // model runner (failable initializer -> Optional)
  private let modelRunner = TemporalHandNetRunner()

  // label map (loads once)
  private lazy var id2label: [Int: String] = loadId2Label()
    
    private let tokenizer = ASLTokenizer(stableFramesRequired: 6, noHandsFramesToEnd: 12)
    
    // iOS -> Flutter: we’ll call this every time we produce a word
    var onWord: ((String) -> Void)?

  // Call this once on app start (or when user opens camera screen)
  func start() {
      
      tokenizer.onComplete = { words in
        print("✅ READY TO SEND (not sending yet):", words)
      }
      
    guard let modelPath = Bundle.main.path(forResource: "hand_landmarker", ofType: "task") else {
      print("hand_landmarker.task not found in app bundle")
      return
    }

    do {
      let options = HandLandmarkerOptions()
      options.baseOptions.modelAssetPath = modelPath
      options.runningMode = .liveStream
      options.numHands = 2
      options.handLandmarkerLiveStreamDelegate = self

      landmarker = try HandLandmarker(options: options)
      print("HandLandmarker ready ✅")
    } catch {
      print("Failed to create HandLandmarker:", error)
    }

    // just so we know labels are available
    print("id2label loaded:", id2label)
  }

  /// Call this for each camera frame you want processed
  func process(pixelBuffer: CVPixelBuffer, timestampMs: Int) {
    guard let landmarker else { return }

    do {
      let mpImage = try MPImage(pixelBuffer: pixelBuffer)
      try landmarker.detectAsync(image: mpImage, timestampInMilliseconds: timestampMs)
    } catch {
      print("detectAsync failed:", error)
    }
  }

  // MARK: - Feature building helpers

  /// Convert one hand to 63 floats = (x,y,z)*21 after making them wrist-relative.
  private func hand63_wristRelative(from landmarks: [NormalizedLandmark]) -> [Float] {
    var out: [Float] = []
    out.reserveCapacity(63)

    guard landmarks.count >= 21 else {
      return Array(repeating: 0.0, count: 63)
    }

    let wrist = landmarks[0]
    let wx = wrist.x
    let wy = wrist.y
    let wz = wrist.z

    for lm in landmarks {
      out.append(Float(lm.x - wx))
      out.append(Float(lm.y - wy))
      out.append(Float(lm.z - wz))
    }
    return out
  }

  /// Build 126-vector for a single frame:
  /// [hand0(63 floats) , hand1(63 floats)]
  /// hand ordering: leftmost wrist.x first. If missing a hand -> zeros.
  private func build126(from result: HandLandmarkerResult) -> [Float] {
    let hands = result.landmarks

    guard hands.count > 0 else {
      return Array(repeating: 0.0, count: 126)
    }

    var handWithWristX: [(idx: Int, wristX: Float)] = []
    for (i, h) in hands.enumerated() {
      let wx = (h.count > 0) ? Float(h[0].x) : 0
      handWithWristX.append((idx: i, wristX: wx))
    }

    handWithWristX.sort { $0.wristX < $1.wristX }

    var first63 = Array(repeating: Float(0.0), count: 63)
    var second63 = Array(repeating: Float(0.0), count: 63)

    if handWithWristX.count >= 1 {
      first63 = hand63_wristRelative(from: hands[handWithWristX[0].idx])
    }
    if handWithWristX.count >= 2 {
      second63 = hand63_wristRelative(from: hands[handWithWristX[1].idx])
    }

    return first63 + second63
  }

  /// Called when buffer reaches 16: build JSON payload and print its bytes
  private func sendBufferPayload(timestampMs: Int) {
    guard frameBuffer.count == bufferSize else { return }

    let payload: [String: Any] = [
      "t": timestampMs,
      "x": frameBuffer
    ]

    if let data = try? JSONSerialization.data(withJSONObject: payload, options: []) {
      // print("prepared payload bytes =", data.count, "frames =", frameBuffer.count)
    } else {
      print("failed to serialize payload")
    }
  }

  // MARK: - Labels

  private func loadId2Label() -> [Int: String] {
    guard let path = Bundle.main.path(forResource: "id2label", ofType: "json") else {
      print("id2label.json not found in app bundle (defaulting to empty)")
      return [:]
    }

    do {
      let data = try Data(contentsOf: URL(fileURLWithPath: path))
      let raw = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] ?? [:]

      var map: [Int: String] = [:]
      for (k, v) in raw {
        if let idx = Int(k), let label = v as? String {
          map[idx] = label
        }
      }
      return map
    } catch {
      print("Failed to load id2label.json:", error)
      return [:]
    }
  }

  private func argmax(_ scores: [Float]) -> (index: Int, value: Float)? {
    guard !scores.isEmpty else { return nil }
    var bestI = 0
    var bestV = scores[0]
    for i in 1..<scores.count {
      if scores[i] > bestV {
        bestV = scores[i]
        bestI = i
      }
    }
    return (bestI, bestV)
  }

  // Convert logits -> probabilities (numerically stable softmax)
  private func softmax(_ scores: [Float]) -> [Float] {
    guard !scores.isEmpty else { return [] }

    let maxScore = scores.max() ?? 0
    let exps = scores.map { expf($0 - maxScore) }
    let sumExp = exps.reduce(0, +)
    guard sumExp > 0 else { return exps.map { _ in 0 } } // avoid div-by-zero

    return exps.map { $0 / sumExp }
  }

  // MARK: - CoreML

  // Turn [[Float]] (16 x 126) into MLMultiArray (1 x 16 x 126) and run CoreML.
  private func runCoreML(on buffer16x126: [[Float]]) {
    guard let runner = modelRunner else {
      print("TemporalHandNetRunner not available")
      return
    }
    guard buffer16x126.count == 16 else { return }
    guard buffer16x126.allSatisfy({ $0.count == 126 }) else {
      print("Bad buffer shape")
      return
    }

    do {
      let x = try MLMultiArray(shape: [1, 16, 126], dataType: .float32)

      // fill in [b=0, t=0..15, f=0..125]
      for t in 0..<16 {
        for f in 0..<126 {
          let idx = t * 126 + f
          x[idx] = NSNumber(value: buffer16x126[t][f])
        }
      }

      guard let scores = runner.predict(scoresInput: x) else {
        print("CoreML predict failed")
        return
      }

      // print raw logits (debug)
      // print("CoreML scores:", scores)

      // convert logits -> probs and print a 0..1 confidence for the best class
      if let best = argmax(scores) {
        let probs = softmax(scores)
        let prob = probs.indices.contains(best.index) ? probs[best.index] : 0
        let label = id2label[best.index] ?? "unknown(\(best.index))"
        print(String(format: "Prediction -> %@ | prob: %.3f", label, prob))
          onWord?(label)
          tokenizer.ingest(word: label)
      }

    } catch {
      print("Failed to create MLMultiArray:", error)
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
      
      // If no hands: feed tokenizer + keep UI consistent
      if result.landmarks.isEmpty {
        tokenizer.ingest(word: "no hands detected")
        onWord?("no hands detected") // your existing UI callback
        return
      }

    print("hands:", result.landmarks.count, "t=", timestampInMilliseconds)

    let frame126 = build126(from: result)

    bufferQueue.async { [weak self] in
      guard let self = self else { return }

      self.frameBuffer.append(frame126)
      if self.frameBuffer.count > self.bufferSize {
        self.frameBuffer.removeFirst(self.frameBuffer.count - self.bufferSize)
      }

      if self.frameBuffer.count == self.bufferSize {
        let snapshot = self.frameBuffer
        let t = timestampInMilliseconds

        // run model off this queue so we don't stall landmark processing
        DispatchQueue.global(qos: .userInitiated).async {
          self.runCoreML(on: snapshot)
        }

        self.sendBufferPayload(timestampMs: t)
      }
    }
  }
}
