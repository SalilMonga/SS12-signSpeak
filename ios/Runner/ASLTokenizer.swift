//
//  ASLTokenizer.swift
//  Runner
//
//  Created by Ryan Hakimi on 2/21/26.
//


import Foundation

/// Collects stable words into a phrase (array of strings).
/// Ends the phrase after N consecutive "no hands detected" frames.
final class ASLTokenizer {

  // --- tune these ---
  private let stableFramesRequired: Int
  private let noHandsFramesToEnd: Int

  // Called when a phrase ends (ready to send to API later)
  var onComplete: (([String]) -> Void)?

  // --- internal state ---
  private var currentCandidate: String? = nil
  private var candidateStreak: Int = 0

  private var phrase: [String] = []
  private var seen = Set<String>() // no duplicates inside phrase

  private var noHandsStreak: Int = 0

  init(stableFramesRequired: Int = 3, noHandsFramesToEnd: Int = 6) {
    self.stableFramesRequired = stableFramesRequired
    self.noHandsFramesToEnd = noHandsFramesToEnd
  }

  func ingest(word raw: String) {
    let word = raw.trimmingCharacters(in: .whitespacesAndNewlines)

    // 1) "no hands" logic ends a phrase
    if word.lowercased() == "no hands detected" {
      noHandsStreak += 1
      // reset candidate tracking while hands are gone
      currentCandidate = nil
      candidateStreak = 0

      if noHandsStreak >= noHandsFramesToEnd {
        finishPhraseIfNeeded()
      }
      return
    }

    // if we see any real word, hands are "back"
    noHandsStreak = 0

    // 2) stability logic (word must repeat across frames)
    if word == currentCandidate {
      candidateStreak += 1
    } else {
      currentCandidate = word
      candidateStreak = 1
    }

    // 3) if stable long enough, add once (no duplicates)
    if candidateStreak >= stableFramesRequired {
      if !word.isEmpty, !seen.contains(word) {
        phrase.append(word)
        seen.insert(word)
        print("Tokenizer: ✅ added word =", word, "phrase so far =", phrase)
      }
      // keep streak from exploding; also prevents re-adding if it stays stable forever
      candidateStreak = stableFramesRequired
    }
  }

  private func finishPhraseIfNeeded() {
    guard !phrase.isEmpty else {
      // nothing to send, just reset
      reset()
      return
    }

    let completed = phrase
    print("Tokenizer: 🧾 phrase COMPLETE =", completed)

    onComplete?(completed)
    reset()
  }

  private func reset() {
    currentCandidate = nil
    candidateStreak = 0
    phrase.removeAll()
    seen.removeAll()
    noHandsStreak = 0
  }
}
