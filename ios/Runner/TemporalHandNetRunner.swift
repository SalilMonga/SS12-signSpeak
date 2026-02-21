import Foundation
import CoreML

// Small wrapper around the CoreML model.
// Handles:
// - loading the model
// - creating input tensor
// - running prediction
// - mapping scores -> label + confidence
final class TemporalHandNetRunner {

  // Load once, reuse forever (faster)
  private let model: TemporalHandNet
  private let id2label: [Int: String]

  init?() {
    let config = MLModelConfiguration()

    do {
      self.model = try TemporalHandNet(configuration: config)
      self.id2label = TemporalHandNetRunner.loadId2Label()
    } catch {
      print("TemporalHandNet failed to load:", error)
      return nil
    }
  }

  // MARK: - Tensor Creation

  /// Creates the (1 x 16 x 126) float tensor the model expects.
  /// We'll fill this with real landmark features later.
  func makeInputTensor() -> MLMultiArray? {
    do {
      let arr = try MLMultiArray(shape: [1, 16, 126], dataType: .float32)

      // zero-init (CoreML memory can be uninitialized)
      for i in 0..<arr.count {
        arr[i] = 0
      }

      return arr
    } catch {
      print("failed to create MLMultiArray:", error)
      return nil
    }
  }

  // MARK: - Prediction

  /// Runs the model and returns raw float scores (length 3)
  func predict(scoresInput x: MLMultiArray) -> [Float]? {
    do {
      let out = try model.prediction(x: x)
      let y = out.var_52   // matches your model output name

      var result: [Float] = []
      result.reserveCapacity(y.count)

      for i in 0..<y.count {
        result.append(y[i].floatValue)
      }

      return result
    } catch {
      print("TemporalHandNet prediction failed:", error)
      return nil
    }
  }

  /// Returns (label, confidence) from tensor input
  func predictLabel(from x: MLMultiArray) -> (label: String, confidence: Float)? {
    guard let scores = predict(scoresInput: x) else { return nil }
    guard let maxIndex = scores.indices.max(by: { scores[$0] < scores[$1] }) else { return nil }

    let confidence = scores[maxIndex]
    let label = id2label[maxIndex] ?? "UNKNOWN"

    return (label, confidence)
  }

  // MARK: - JSON Label Loading

  private static func loadId2Label() -> [Int: String] {
    guard let url = Bundle.main.url(forResource: "id2label", withExtension: "json") else {
      print("id2label.json not found")
      return [:]
    }

    do {
      let data = try Data(contentsOf: url)
      let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

      var map: [Int: String] = [:]
      for (k, v) in raw {
        if let id = Int(k), let label = v as? String {
          map[id] = label
        }
      }

      return map
    } catch {
      print("failed to load id2label:", error)
      return [:]
    }
  }

  // MARK: - Quick Smoke Test

  func testRun() {
    guard let x = makeInputTensor() else { return }
    guard let result = predictLabel(from: x) else { return }

    print("Prediction -> \(result.label) | confidence: \(result.confidence)")
  }
}
