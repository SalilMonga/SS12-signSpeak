import Foundation

final class ASLRouter {
    private let store: TemplateStore

    init() throws {
        self.store = try TemplateStore(jsonFileName: "templates")
    }

    func respond(fromGloss gloss: String) -> (intentKey: String, output: String, slots: [String: String]) {
        let tokens = tokenize(gloss)
        let intentKey = detectIntentKey(tokens)
        let slots = extractSlots(tokens, intentKey: intentKey)

        let template = store.randomTemplate(for: intentKey, slots: slots)
        let output = TemplateRenderer.render(template, slots: slots)

        return (intentKey, output, slots)
    }

    // MARK: - Intent (switch rules)

    private func detectIntentKey(_ tokens: [String]) -> String {
        for t in tokens {
            switch t {
            case "INTERPRETER": return "interpreter"
            case "WHERE": return "askLocation"
            case "LEFT", "RIGHT", "STRAIGHT", "UPSTAIRS", "DOWNSTAIRS": return "askDirections"
            case "COST", "PRICE", "PAY", "MONEY": return "askCost"
            case "WHEN": return "askTime"
            case "NEED": return "need"
            case "WANT": return "want"
            case "HELP": return "help"
            case "HI", "HELLO", "HEY": return "greet"
            case "BYE", "GOODBYE": return "goodbye"
            case "THANKS", "THANK", "THANK-YOU": return "thanks"
            case "SORRY": return "apologize"
            case "YES": return "confirmYes"
            case "NO": return "confirmNo"
            default: continue
            }
        }
        return "unknown"
    }

    // MARK: - Slots (very basic starter)

    private func extractSlots(_ tokens: [String], intentKey: String) -> [String: String] {
        var slots: [String: String] = [:]

        let interrogatives: [String: String] = [
            "WHERE": "Where", "WHAT": "What", "WHO": "Who", "WHEN": "When", "WHY": "Why", "HOW": "How"
        ]
        let directions: [String: String] = [
            "LEFT": "left", "RIGHT": "right", "STRAIGHT": "straight", "UPSTAIRS": "upstairs", "DOWNSTAIRS": "downstairs"
        ]
        let places: [String: String] = [
            "BATHROOM": "the restroom", "RESTROOM": "the restroom", "EXIT": "the exit", "ENTRANCE": "the entrance",
            "FRONTDESK": "the front desk", "DESK": "the front desk", "ELEVATOR": "the elevator", "STAIRS": "the stairs"
        ]

        // INTERROGATIVE
        for t in tokens {
            if let q = interrogatives[t] { slots["INTERROGATIVE"] = q; break }
        }

        // DIRECTION
        for t in tokens {
            if let d = directions[t] { slots["DIRECTION"] = d; break }
        }

        // PLACE
        for t in tokens {
            if let p = places[t] { slots["PLACE"] = p; break }
        }

        // NAME pattern: "NAME JOHN" or "MY NAME JOHN"
        if let idx = tokens.firstIndex(of: "NAME"), idx + 1 < tokens.count {
            slots["NAME"] = pretty(tokens[idx + 1])
        } else if let idx = findSequence(["MY","NAME"], in: tokens), idx + 2 < tokens.count {
            slots["NAME"] = pretty(tokens[idx + 2])
        }

        // NOUN = first non-signal content token (simple heuristic)
        let signal = Set(["WHERE","WHAT","WHO","WHEN","WHY","HOW","WANT","NEED","GET","HELP","INTERPRETER",
                          "HI","HELLO","HEY","BYE","GOODBYE","THANKS","SORRY","YES","NO"])
        let stop = Set(["I","ME","MY","YOU","YOUR","WE","THE","A","AN","TO","FOR","WITH","PLEASE","PLS","NOW"])

        let content = tokens.filter { !signal.contains($0) && !stop.contains($0) && places[$0] == nil && interrogatives[$0] == nil && directions[$0] == nil }
        if let first = content.first {
            slots["NOUN"] = first.lowercased()
        }

        return slots
    }

    // MARK: - Tokenize/Helpers

    private func tokenize(_ gloss: String) -> [String] {
        let upper = gloss.uppercased()
        let allowed = CharacterSet.alphanumerics.union(.whitespacesAndNewlines).union(CharacterSet(charactersIn: "-$'"))
        let filtered = String(upper.unicodeScalars.map { allowed.contains($0) ? Character($0) : " " })
        return filtered.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    private func pretty(_ token: String) -> String {
        let lower = token.lowercased()
        return lower.prefix(1).uppercased() + lower.dropFirst()
    }

    private func findSequence(_ seq: [String], in tokens: [String]) -> Int? {
        guard !seq.isEmpty, tokens.count >= seq.count else { return nil }
        for i in 0...(tokens.count - seq.count) {
            if Array(tokens[i..<(i + seq.count)]) == seq { return i }
        }
        return nil
    }
}