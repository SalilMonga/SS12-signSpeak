import Foundation
import CoreML

// Runs the TemporalHandNet CoreML model and returns raw scores/logits as [Float].
// This version does NOT depend on a specific output name like "var_52".
final class TemporalHandNetRunner {

  private let model: TemporalHandNet

  init?() {
    let config = MLModelConfiguration()
    do {
      self.model = try TemporalHandNet(configuration: config)
    } catch {
      print("TemporalHandNet failed to load:", error)
      return nil
    }
  }

  /// Runs prediction on input x shaped (1 x 16 x 126)
  /// Returns raw scores as [Float] (whatever the model outputs)
  func predict(scoresInput x: MLMultiArray) -> [Float]? {
    do {
      // Run the generated model wrapper
      let out = try model.prediction(x: x)

      // ---- Dynamic output lookup (no hardcoded name) ----
      // The generated output object still conforms to MLFeatureProvider,
      // so we can ask it what outputs exist.
      let provider = out as MLFeatureProvider
      let outputNames = Array(provider.featureNames)

      guard let firstName = outputNames.first else {
        print("TemporalHandNet: no outputs found")
        return nil
      }

      guard let fv = provider.featureValue(for: firstName) else {
        print("TemporalHandNet: missing featureValue for output:", firstName)
        return nil
      }

      guard let y = fv.multiArrayValue else {
        print("TemporalHandNet: output is not an MLMultiArray. Output:", firstName)
        return nil
      }

      // Convert MLMultiArray -> [Float]
      var result: [Float] = []
      result.reserveCapacity(y.count)
      for i in 0..<y.count {
        result.append(y[i].floatValue)
      }

      // Debug once if you want to verify the name:
      // print("TemporalHandNet output name:", firstName, "count:", y.count)

      return result

    } catch {
      print("TemporalHandNet prediction failed:", error)
      return nil
    }
  }
}
