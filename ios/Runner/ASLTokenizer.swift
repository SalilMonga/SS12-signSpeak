//
//  ASLTokenizer.swift
//  Runner
//
//  Created by Ryan Hakimi on 2/21/26.
//


import Foundation

// Collects unique ASL words, waits for a word to be "stable" for N updates,
// then appends it (no duplicates). If we see "no hands detected" for long
// enough, we end the phrase + POST it to FastAPI.
final class ASLTokenizer {

  // Called when a word passes stability checks and is accepted.
  var onStableWord: ((String) -> Void)?

  // ====== Tweakables ======
  // how many consecutive updates must match before we accept the word
  private let stableFramesRequired: Int

  // how many consecutive "no hands detected" updates ends the phrase + sends
  private let noHandsEndRequired: Int

  // endpoint: http://<ip>:8000/generate
  private let endpointURL: URL

  // exact string that represents "no hands"
  private let noHandsToken = "no hands detected"

  // ====== State ======
  private var currentStableWord: String? = nil
  private var stableCount: Int = 0

  private var noHandsCount: Int = 0

  // collected unique words (no duplicates)
  private var words: [String] = []
  private var seen: Set<String> = []

  // single serial queue so we don't fight with async callbacks
  private let q = DispatchQueue(label: "asl.tokenizer.queue")

  init(
    endpoint: String,
    stableFramesRequired: Int = 3,
    noHandsEndRequired: Int = 8
  ) {
    if let url = URL(string: endpoint) {
      self.endpointURL = url
    } else {
      assertionFailure("Invalid endpoint URL string: \(endpoint). Falling back to default endpoint.")
      self.endpointURL = URL(string: "http://localhost:8000/generate")!
    }
    self.stableFramesRequired = stableFramesRequired
    self.noHandsEndRequired = noHandsEndRequired
  }

  /// Call this on EVERY model output (word OR "no hands detected")
  func ingest(word raw: String) {
    q.async { [weak self] in
      guard let self else { return }
      let word = raw.trimmingCharacters(in: .whitespacesAndNewlines)

      // ---- Handle "no hands" ----
      if word.lowercased() == self.noHandsToken {
        self.noHandsCount += 1

        // reset word stability tracking when no-hands comes in
        self.currentStableWord = nil
        self.stableCount = 0

        // if we've been no-hands for long enough, end phrase + send
        if self.noHandsCount >= self.noHandsEndRequired {
          self.flushAndSend()
        }
        return
      }

      // not "no hands" => reset no-hands counter
      self.noHandsCount = 0

      // ---- Stability logic for real words ----
      if self.currentStableWord == word {
        self.stableCount += 1
      } else {
        self.currentStableWord = word
        self.stableCount = 1
      }

      // Once stable enough, accept it (only if not already in array)
      if self.stableCount >= self.stableFramesRequired {
        // reset stability so we don't re-add instantly
        self.currentStableWord = nil
        self.stableCount = 0

        // no duplicates
        if !self.seen.contains(word) {
          self.words.append(word)
          self.seen.insert(word)
          self.onStableWord?(word)
          print("Tokenizer ✅ added:", word, "->", self.words)
        } else {
          // seen before, ignore
          // print("Tokenizer (dup) ignoring:", word)
        }
      }
    }
  }

  // Ends the current phrase and POSTs it (if non-empty).
  private func flushAndSend() {
    guard !words.isEmpty else {
      // nothing to send, just reset counters
      self.noHandsCount = 0
      return
    }

    let payloadWords = self.words
    self.words.removeAll()
    self.seen.removeAll()
    self.noHandsCount = 0

    print("Tokenizer 🚀 sending:", payloadWords)

    // Build JSON: { "aslWords": ["I","WANT","APPLE"] }
    let body: [String: Any] = ["aslWords": payloadWords]
    guard let json = try? JSONSerialization.data(withJSONObject: body, options: []) else {
      print("Tokenizer ❌ failed to serialize JSON")
      return
    }

    var req = URLRequest(url: endpointURL)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.httpBody = json
    req.timeoutInterval = 3.0

    URLSession.shared.dataTask(with: req) { data, resp, err in
      if let err {
        let nsError = err as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut {
          print("Tokenizer ⏳ Waiting for hand... (backend timeout)")
        } else {
          print("Tokenizer ⚠️ Backend unavailable. Waiting for hand...")
        }
        return
      }

      if let http = resp as? HTTPURLResponse {
        if (200...299).contains(http.statusCode) {
          print("Tokenizer ✅ POST status:", http.statusCode)
        } else {
          print("Tokenizer ⚠️ Backend responded with status \(http.statusCode)")
        }
      }

      // optional: print response body (helpful for debugging)
      if let data, let s = String(data: data, encoding: .utf8) {
        print("Tokenizer response:", s)
      }
    }.resume()
  }
}