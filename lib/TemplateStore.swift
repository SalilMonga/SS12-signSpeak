import Foundation

enum TemplateStoreError: Error {
    case fileNotFound(String)
    case decodeFailed(Error)
}

final class TemplateStore {
    // Maps intentKey -> [template strings]
    private(set) var templates: [String: [String]]

    init(jsonFileName: String = "templates", bundle: Bundle = .main) throws {
        guard let url = bundle.url(forResource: jsonFileName, withExtension: "json") else {
            throw TemplateStoreError.fileNotFound("\(jsonFileName).json")
        }

        do {
            let data = try Data(contentsOf: url)
            self.templates = try JSONDecoder().decode([String: [String]].self, from: data)
        } catch {
            throw TemplateStoreError.decodeFailed(error)
        }
    }

    /// Returns a random template for an intentKey, optionally preferring ones whose required slots exist.
    func randomTemplate(
        for intentKey: String,
        slots: [String: String],
        fallbackKey: String = "unknown"
    ) -> String {
        let list = templates[intentKey] ?? templates[fallbackKey] ?? ["Sorry—can you rephrase that?"]

        // Prefer templates that can be fully filled (all placeholders present in slots)
        let viable = list.filter { template in
            missingPlaceholders(in: template, slots: slots).isEmpty
        }

        return (viable.randomElement() ?? list.randomElement())!
    }

    private func missingPlaceholders(in template: String, slots: [String: String]) -> [String] {
        // finds {PLACEHOLDER}
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

// Simple placeholder renderer: replaces {KEY} with slots["KEY"] if present.
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