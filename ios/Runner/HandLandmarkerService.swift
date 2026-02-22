import Foundation
import AVFoundation
import CoreML
import MediaPipeTasksVision

// Handles: loading the .task model + running hand landmarks on a frame
// Adds: wrist-relative 126-vector + 16-frame ring buffer, CoreML run,
// id2label mapping, numerically-stable softmax, + gate/tokenizer wiring.
final class HandLandmarkerService: NSObject {

  private var landmarker: HandLandmarker?

  // Used to avoid spamming "no hands detected"
  private var wasNoHands: Bool = false
    
    // throttle "no hands" logging so it doesn't spam every frame
    private var lastNoHandsLogMs: Int = 0
    private let noHandsLogEveryMs: Int = 800   // tweak later (800ms feels nice)
    
  // ring buffer for last 16 frames (each frame -> [Float] length 126)
  private var frameBuffer: [[Float]] = []
  private let bufferSize = 16
  private let bufferQueue = DispatchQueue(label: "hand.buffer.queue")

  // CoreML runner (optional in case model init fails)
  private let modelRunner: TemporalHandNetRunner? = TemporalHandNetRunner()

  // Gate logic (conf/margin/stable/cooldown/etc.)
    private let gate = PredictionGate(
      confThr: 0.65,
      marginThr: 0.20,
      stableN: 4,
      cooldownS: 1.0,
      minGapRepeatS: 1.5
    )

  // Tokenizer (phrase builder)
  private let tokenizer = ASLTokenizer(stableFramesRequired: 1, noHandsFramesToEnd: 12)

  // label map (loads once)
  private lazy var id2label: [Int: String] = loadId2Label()

  // iOS -> Flutter: called whenever we produce a word for UI
  var onWord: ((String) -> Void)?

  // iOS -> Flutter: called when tokenizer completes a phrase
  var onPhraseComplete: (([String]) -> Void)?

  // Call this once on app start (or when user opens camera screen)
  func start() {
    tokenizer.onComplete = { [weak self] words in
      print("Tokenizer: 🧾 phrase COMPLETE =", words)
      self?.onPhraseComplete?(words)
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
    guard landmarks.count >= 21 else { return Array(repeating: 0.0, count: 63) }

    var out: [Float] = []
    out.reserveCapacity(63)

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
  /// [left_hand(63 floats) , right_hand(63 floats)]
  /// Uses MediaPipe handedness labels ("Left"/"Right") to assign slots,
  /// with wrist-x fallback if label is unavailable. Matches Python pipeline.
  private func build126(from result: HandLandmarkerResult) -> [Float] {
    let hands = result.landmarks
    guard !hands.isEmpty else { return Array(repeating: 0.0, count: 126) }

    var left63 = Array(repeating: Float(0.0), count: 63)
    var right63 = Array(repeating: Float(0.0), count: 63)

    let handednessAll = result.handedness  // [[ResultCategory]] parallel to landmarks

    for i in 0..<min(hands.count, 2) {
      let vec = hand63_wristRelative(from: hands[i])

      // Try to get the handedness label from MediaPipe classification
      var label: String? = nil
      if i < handednessAll.count, !handednessAll[i].isEmpty {
        label = handednessAll[i][0].categoryName
      }

      // Fallback: use wrist x position (same as Python)
      if label == nil {
        let wristX = hands[i].count > 0 ? Float(hands[i][0].x) : 0.5
        label = wristX < 0.5 ? "Left" : "Right"
      }

      if label?.lowercased().hasPrefix("l") == true {
        left63 = vec
      } else {
        right63 = vec
      }
    }

    return left63 + right63
  }

  /// Called when buffer reaches 16: build JSON payload (kept for later networking)
  private func sendBufferPayload(timestampMs: Int) {
    guard frameBuffer.count == bufferSize else { return }

    let payload: [String: Any] = [
      "t": timestampMs,
      "x": frameBuffer
    ]

    if let data = try? JSONSerialization.data(withJSONObject: payload, options: []) {
      _ = data
      // (no log)
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

  // Convert logits -> probabilities (numerically stable softmax)
  private func softmax(_ scores: [Float]) -> [Float] {
    guard !scores.isEmpty else { return [] }

    let maxScore = scores.max() ?? 0
    let exps = scores.map { expf($0 - maxScore) }
    let sumExp = exps.reduce(0, +)
    guard sumExp > 0 else { return exps.map { _ in 0 } }

    return exps.map { $0 / sumExp }
  }

  private func top2(from probs: [Float]) -> (i1: Int, p1: Float, i2: Int, p2: Float)? {
    guard probs.count >= 2 else { return nil }

    var best1 = (idx: 0, p: probs[0])
    var best2 = (idx: 1, p: probs[1])
    if best2.p > best1.p { swap(&best1, &best2) }

    if probs.count > 2 {
      for i in 2..<probs.count {
        let p = probs[i]
        if p > best1.p {
          best2 = best1
          best1 = (i, p)
        } else if p > best2.p {
          best2 = (i, p)
        }
      }
    }
    return (best1.idx, best1.p, best2.idx, best2.p)
  }

  // MARK: - CoreML

  /// Turn [[Float]] (16 x 126) into MLMultiArray (1 x 16 x 126) and run CoreML.
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

      for t in 0..<16 {
        for f in 0..<126 {
          let idx = t * 126 + f
          x[idx] = NSNumber(value: buffer16x126[t][f])
        }
      }

      guard let logits = runner.predict(scoresInput: x) else {
        print("CoreML predict failed")
        return
      }

      let probs = softmax(logits)
      guard let t2 = top2(from: probs) else { return }

      let top1Label = id2label[t2.i1] ?? "unknown(\(t2.i1))"
      let top1Prob = t2.p1
      let top2Prob = t2.p2

      if let accepted = gate.ingest(top1Word: top1Label, top1Prob: top1Prob, top2Prob: top2Prob) {
        tokenizer.ingest(word: accepted)
        onWord?(accepted)
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

      // --- NO HANDS: log (throttled) + reset gate/tokenizer + clear buffer
      if result.landmarks.isEmpty {
        // log only on transition OR every ~800ms (prevents spam)
        if !wasNoHands || (timestampInMilliseconds - lastNoHandsLogMs) >= noHandsLogEveryMs {
          print("no hands detected")
          lastNoHandsLogMs = timestampInMilliseconds
        }
        wasNoHands = true

        gate.resetForNoHands()
        tokenizer.ingest(word: "no hands detected")
        onWord?("no hands detected")

        bufferQueue.async { [weak self] in
          self?.frameBuffer.removeAll()
        }

        return
      } else {
        // hands came back, unlock the transition log next time
        wasNoHands = false
      }

    // hands are back
    wasNoHands = false

    // (optional) spammy — keep off
    // print("hands:", result.landmarks.count, "t=", timestampInMilliseconds)

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

        DispatchQueue.global(qos: .userInitiated).async {
          self.runCoreML(on: snapshot)
        }

        self.sendBufferPayload(timestampMs: t)
      }
    }
  }
}
