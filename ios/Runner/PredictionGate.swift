//
//  PredictionGate.swift
//  Runner
//
//  Created by Ryan Hakimi on 2/21/26.
//


import Foundation

/// Sits between model probs -> "accepted word" events.
/// Adds: confidence threshold, margin gating, stable run, cooldown, repeat gap.
final class PredictionGate {

  // --- tuning knobs (your teammate’s list) ---
  private let confThr: Float
  private let marginThr: Float
  private let stableN: Int
  private let cooldownS: Double
  private let minGapRepeatS: Double

  // --- internal state ---
  private var candidate: String? = nil
  private var stableCount: Int = 0

  private var lastAcceptedAt: TimeInterval = 0
  private var lastAcceptedWord: String? = nil
  private var lastSeenAtForWord: [String: TimeInterval] = [:]

  init(
    confThr: Float = 0.55,
    marginThr: Float = 0.12,
    stableN: Int = 3,
    cooldownS: Double = 0.75,
    minGapRepeatS: Double = 1.5
  ) {
    self.confThr = confThr
    self.marginThr = marginThr
    self.stableN = max(1, stableN)
    self.cooldownS = cooldownS
    self.minGapRepeatS = minGapRepeatS
  }

  /// Call this when hands disappear. Keeps model from being “sticky”.
  func resetForNoHands() {
    candidate = nil
    stableCount = 0
  }

  /// Feed the top1/top2 results each time you run the model.
  /// - Returns: accepted word if this frame causes an acceptance; else nil.
  func ingest(top1Word: String, top1Prob: Float, top2Prob: Float, now: TimeInterval = Date().timeIntervalSince1970) -> String? {

    // 1) global cooldown after any acceptance
    if lastAcceptedAt > 0, (now - lastAcceptedAt) < cooldownS {
      return nil
    }

    // 2) conf threshold
    if top1Prob < confThr {
      candidate = nil
      stableCount = 0
      return nil
    }

    // 3) margin gating
    let margin = top1Prob - top2Prob
    if margin < marginThr {
      candidate = nil
      stableCount = 0
      return nil
    }

    // 4) stable run
    if candidate == top1Word {
      stableCount += 1
    } else {
      candidate = top1Word
      stableCount = 1
    }

    if stableCount < stableN {
      return nil
    }

    // 5) repeat gap (don’t spam same word)
    if let last = lastSeenAtForWord[top1Word], (now - last) < minGapRepeatS {
      // keep it from “locking” by capping stableCount
      stableCount = stableN
      return nil
    }

    // ACCEPT ✅
    lastAcceptedAt = now
    lastAcceptedWord = top1Word
    lastSeenAtForWord[top1Word] = now

    print(String(format: "[DETECTED] %@ p=%.3f margin=%.3f", top1Word, top1Prob, margin))

    // prevent re-accepting instantly if it stays stable
    stableCount = stableN
    return top1Word
  }
}