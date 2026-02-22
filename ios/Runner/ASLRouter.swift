import Foundation

final class ASLRouter {
    private let store: TemplateStore

    init(store: TemplateStore) {
        self.store = store
    }

    func respond(fromWords words: [String]) -> String {
        let tokens = words.map { $0.uppercased() }
        let intentKey = detectIntentKey(tokens)
        let slots = extractSlots(tokens, intentKey: intentKey)

        let template = store.randomTemplate(for: intentKey, slots: slots)
        return TemplateRenderer.render(template, slots: slots)
    }

    private func detectIntentKey(_ tokens: [String]) -> String {
        for t in tokens {
            switch t {
            case "WHERE": return "askLocation"
            case "LEFT", "RIGHT", "STRAIGHT", "UPSTAIRS", "DOWNSTAIRS": return "askDirections"
            case "INTERPRETER": return "interpreter"
            case "NEED": return "need"
            case "WANT": return "want"
            case "GET": return "get"
            case "HELP": return "help"
            case "HI", "HELLO", "HEY": return "greet"
            case "BYE", "GOODBYE": return "goodbye"
            case "THANKS", "THANK": return "thanks"
            case "SORRY": return "apologize"
            case "YES": return "confirmYes"
            case "NO": return "confirmNo"
            default: continue
            }
        }
        return "unknown"
    }

    private func extractSlots(_ tokens: [String], intentKey: String) -> [String: String] {
    var slots: [String: String] = [:]

    // 1) Expanded interrogatives / directions
    let interrogatives: [String: String] = [
        "WHERE": "Where", "WHAT": "What", "WHO": "Who", "WHEN": "When", "WHY": "Why", "HOW": "How", "WHICH": "Which"
    ]
    let directions: [String: String] = [
        "LEFT": "left", "RIGHT": "right", "STRAIGHT": "straight", "FORWARD": "straight",
        "UP": "up", "DOWN": "down", "UPSTAIRS": "upstairs", "DOWNSTAIRS": "downstairs",
        "NORTH": "north", "SOUTH": "south", "EAST": "east", "WEST": "west"
    ]

    // 2) Expanded places (vocabulary)
    let places: [String: String] = [
        "BATHROOM": "the restroom", "RESTROOM": "the restroom", "TOILET": "the restroom",
        "EXIT": "the exit", "ENTRANCE": "the entrance",
        "FRONTDESK": "the front desk", "FRONT-DESK": "the front desk", "DESK": "the front desk", "RECEPTION": "reception",
        "ELEVATOR": "the elevator", "LIFT": "the elevator",
        "STAIRS": "the stairs", "LOBBY": "the lobby", "HALL": "the hallway", "HALLWAY": "the hallway",
        "OFFICE": "the office", "ROOM": "the room", "BUILDING": "the building",
        "SECURITY": "security", "INFORMATION": "information", "INFO": "information", "HELPDESK": "the help desk", "HELP-DESK": "the help desk",
        "CLINIC": "the clinic", "HOSPITAL": "the hospital", "PHARMACY": "the pharmacy", "ER": "the emergency room",
        "PARKING": "parking", "GARAGE": "the parking garage",
        "BUS": "the bus stop", "TRAIN": "the train station", "STATION": "the station",
        "GATE": "the gate", "TERMINAL": "the terminal",
        "CAFE": "the cafe", "CAFETERIA": "the cafeteria", "RESTAURANT": "the restaurant"
    ]

    // 3) Expanded nouns (things/services)
    let nouns: [String: String] = [
        "APPLE": "apple", "BANANA": "banana", "WATER": "water", "FOOD": "food", "DRINK": "a drink",
        "WIFI": "Wi-Fi", "INTERNET": "internet", "PASSWORD": "the password",
        "CHARGER": "a charger", "PHONE": "my phone", "LAPTOP": "my laptop",
        "TICKET": "a ticket", "RECEIPT": "a receipt", "FORM": "a form", "ID": "my ID", "WALLET": "my wallet", "BAG": "my bag",
        "HELP": "help", "ASSISTANCE": "assistance",
        "INTERPRETER": "an ASL interpreter", "TRANSLATOR": "a translator", "CAPTIONS": "captions",
        "DOCTOR": "a doctor", "NURSE": "a nurse", "MEDICINE": "medicine"
    ]

    // Words that should not be treated as content
    let signal: Set<String> = [
        "WHERE","WHAT","WHO","WHEN","WHY","HOW","WHICH",
        "WANT","NEED","GET","HELP","INTERPRETER",
        "HI","HELLO","HEY","BYE","GOODBYE","THANKS","THANK","SORRY",
        "YES","NO",
        "LEFT","RIGHT","STRAIGHT","FORWARD","UP","DOWN","UPSTAIRS","DOWNSTAIRS","NORTH","SOUTH","EAST","WEST"
    ]
    let stop: Set<String> = ["I","ME","MY","YOU","YOUR","WE","THE","A","AN","TO","FOR","WITH","PLEASE","PLS","NOW"]

    // INTERROGATIVE
    for t in tokens { if let q = interrogatives[t] { slots["INTERROGATIVE"] = q; break } }

    // DIRECTION
    for t in tokens { if let d = directions[t] { slots["DIRECTION"] = d; break } }

    // PLACE
    for t in tokens { if let p = places[t] { slots["PLACE"] = p; break } }

    // NAME: NAME JOHN / MY NAME JOHN
    if let idx = tokens.firstIndex(of: "NAME"), idx + 1 < tokens.count {
        slots["NAME"] = pretty(tokens[idx + 1])
    } else if let idx = findSequence(["MY","NAME"], in: tokens), idx + 2 < tokens.count {
        slots["NAME"] = pretty(tokens[idx + 2])
    }

    // NOUN: first from dictionary
    for t in tokens {
        if let n = nouns[t] {
            slots["NOUN"] = n
            break
        }
    }

    // CONTENT tokens: leftover candidates
    let content = tokens.filter { t in
        !signal.contains(t) &&
        !stop.contains(t) &&
        interrogatives[t] == nil &&
        directions[t] == nil &&
        places[t] == nil
    }

    // Fallbacks:
    // If intent is askLocation and PLACE is missing, treat first content word as PLACE.
    if intentKey == "askLocation" || intentKey == "askDirections" {
        if slots["PLACE"] == nil, let c = content.first {
            slots["PLACE"] = "the \(c.lowercased())"
        }
    }

    // If NOUN is missing, use first content word as NOUN (or join two words for a phrase)
    if slots["NOUN"] == nil, let first = content.first {
        if content.count >= 2 {
            // e.g., "APPLE JUICE" -> "apple juice"
            slots["NOUN"] = "\(content[0].lowercased()) \(content[1].lowercased())"
        } else {
            slots["NOUN"] = first.lowercased()
        }
    }

    return slots
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