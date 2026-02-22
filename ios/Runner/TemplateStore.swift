import Foundation

enum TemplateStoreError: Error {
    case decodeFailed(Error)
}

final class TemplateStore {
    private(set) var templates: [String: [String]] = [:]

    init() {}

    func loadFromJSONString(_ json: String) throws {
        do {
            let data = Data(json.utf8)
            self.templates = try JSONDecoder().decode([String: [String]].self, from: data)
        } catch {
            throw TemplateStoreError.decodeFailed(error)
        }
    }

    func randomTemplate(for intentKey: String, slots: [String: String], fallbackKey: String = "unknown") -> String {
    let list = templates[intentKey] ?? templates[fallbackKey] ?? ["Sorry—can you rephrase that?"]

    // First: templates whose placeholders can all be filled
    let viable = list.filter { TemplateStore.missingPlaceholders(in: $0, slots: slots).isEmpty }

    // If NOUN exists, prioritize templates that actually contain {NOUN}
    if slots["NOUN"] != nil {
        let nounFirst = viable.filter { $0.contains("{NOUN}") }
        if let chosen = nounFirst.randomElement() {
            return chosen
        }
    }

    // Next: any viable template
    if let chosen = viable.randomElement() {
        return chosen
    }

    // Fallback: anything (even if it contains unfillable placeholders)
    return list.randomElement()!
}

    private static func missingPlaceholders(in template: String, slots: [String: String]) -> [String] {
        let pattern = #"\{([A-Z_]+)\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = template as NSString
        let matches = regex.matches(in: template, range: NSRange(location: 0, length: ns.length))
        var missing: [String] = []
        for m in matches {
            let key = ns.substring(with: m.range(at: 1))
            if slots[key] == nil { missing.append(key) }
        }
        return missing
    }
}

enum TemplateRenderer {
    static func render(_ template: String, slots: [String: String]) -> String {
        let pattern = #"\{([A-Z_]+)\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return template }
        let ns = template as NSString
        let matches = regex.matches(in: template, range: NSRange(location: 0, length: ns.length))

        var result = template
        for m in matches.reversed() {
            let key = ns.substring(with: m.range(at: 1))
            guard let value = slots[key],
                  let r = Range(m.range(at: 0), in: result) else { continue }
            result.replaceSubrange(r, with: value)
        }
        return result
    }
}