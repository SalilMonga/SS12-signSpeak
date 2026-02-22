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
    // Bathrooms
    "BATHROOM": "the restroom", "RESTROOM": "the restroom", "TOILET": "the restroom",
    "WASHROOM": "the restroom", "MEN": "the men's restroom", "WOMEN": "the women's restroom",

    // Entry/exit/navigation
    "EXIT": "the exit", "ENTRANCE": "the entrance", "DOOR": "the door",
    "LOBBY": "the lobby", "HALL": "the hallway", "HALLWAY": "the hallway",
    "FLOOR": "this floor", "UPSTAIRS": "upstairs", "DOWNSTAIRS": "downstairs",

    // Desks / support
    "FRONTDESK": "the front desk", "FRONT-DESK": "the front desk", "DESK": "the front desk",
    "RECEPTION": "reception", "CHECKIN": "check-in", "CHECK-IN": "check-in",
    "INFORMATION": "information", "INFO": "information",
    "HELPDESK": "the help desk", "HELP-DESK": "the help desk", "CUSTOMERSERVICE": "customer service",
    "CUSTOMER-SERVICE": "customer service",

    // Movement
    "ELEVATOR": "the elevator", "LIFT": "the elevator",
    "STAIRS": "the stairs", "STAIR": "the stairs", "ESCALATOR": "the escalator",

    // Rooms / buildings
    "OFFICE": "the office", "ROOM": "the room", "BUILDING": "the building",
    "WAITING": "the waiting area", "WAITINGROOM": "the waiting room", "WAITING-ROOM": "the waiting room",
    "CONFERENCE": "the conference room", "MEETING": "the meeting room",

    // Security / safety
    "SECURITY": "security", "POLICE": "police", "GUARD": "security",
    "FIRSTAID": "first aid", "FIRST-AID": "first aid",

    // Medical
    "CLINIC": "the clinic", "HOSPITAL": "the hospital", "PHARMACY": "the pharmacy",
    "ER": "the emergency room", "EMERGENCY": "the emergency room",
    "LAB": "the lab", "XRAY": "X-ray", "X-RAY": "X-ray",
    "RADIOLOGY": "radiology", "IMAGING": "imaging",

    // Transport / travel
    "PARKING": "parking", "GARAGE": "the parking garage", "LOT": "the parking lot",
    "BUS": "the bus stop", "BUSSTOP": "the bus stop", "BUS-STOP": "the bus stop",
    "TRAIN": "the train station", "STATION": "the station", "SUBWAY": "the subway",
    "GATE": "the gate", "TERMINAL": "the terminal", "BAGGAGE": "baggage claim",
    "BAGGAGECLAIM": "baggage claim", "BAGGAGE-CLAIM": "baggage claim",
    "TSA": "security screening", "SECURITYCHECK": "security screening", "SECURITY-CHECK": "security screening",
    "WORLD": "the world",

    // Food / amenities
    "CAFE": "the cafe", "CAFETERIA": "the cafeteria", "RESTAURANT": "the restaurant",
    "FOODCOURT": "the food court", "FOOD-COURT": "the food court",
    "VENDING": "the vending machines",

    // Facilities
    "ATM": "the ATM", "BANK": "the bank",
    "ELECTRICAL": "electrical", "MAINTENANCE": "maintenance",
    "LOSTFOUND": "lost and found", "LOST-FOUND": "lost and found",
    "RESTAREA": "the rest area", "REST-AREA": "the rest area",

    // Education / campus-ish (optional)
    "CLASS": "the classroom", "CLASSROOM": "the classroom", "LECTURE": "the lecture hall",
    "LIBRARY": "the library", "STUDENTCENTER": "the student center", "STUDENT-CENTER": "the student center"
    ]

    // 3) Expanded nouns (things/services)
    let nouns: [String: String] = [
    // Food/drink (common)
    "APPLE": "apple", "BANANA": "banana", "ORANGE": "orange", "GRAPES": "grapes",
    "WATER": "water", "JUICE": "juice", "SODA": "soda", "COFFEE": "coffee", "TEA": "tea",
    "FOOD": "food", "SNACK": "a snack",

    // Tech / access
    "WIFI": "Wi-Fi", "WI-FI": "Wi-Fi", "INTERNET": "internet",
    "PASSWORD": "the password", "LOGIN": "login", "ACCOUNT": "my account",
    "CHARGER": "a charger", "CHARGE": "charging", "CABLE": "a cable",
    "PHONE": "my phone", "CELL": "my phone", "MOBILE": "my phone",
    "LAPTOP": "my laptop", "COMPUTER": "a computer", "TABLET": "a tablet",
    "APP": "the app", "EMAIL": "email", "TEXT": "a text message", 
    "KEYS": "keys", "ROCK": "rock",

    // Admin / docs / payments
    "TICKET": "a ticket", "PASS": "a pass", "RESERVATION": "a reservation",
    "RECEIPT": "a receipt", "REFUND": "a refund",
    "FORM": "a form", "PAPER": "paperwork", "DOCUMENT": "a document",
    "ID": "my ID", "LICENSE": "my ID", "PASSPORT": "my passport",
    "CARD": "my card", "CREDIT": "a credit card", "DEBIT": "a debit card",
    "CASH": "cash", "MONEY": "money", "PAYMENT": "a payment", "PRICE": "the price", "COST": "the cost",

    // Personal items
    "WALLET": "my wallet", "BAG": "my bag", "BACKPACK": "my backpack", "PURSE": "my purse",
    "KEY": "my key", "KEYS": "my keys", "WATCH": "my watch", "GLASSES": "my glasses",

    // Help / communication
    "HELP": "help", "ASSISTANCE": "assistance", "SUPPORT": "support",
    "INTERPRETER": "an ASL interpreter", "TRANSLATOR": "a translator",
    "CAPTIONS": "captions", "CAPTION": "captions",

    // Medical
    "DOCTOR": "a doctor", "NURSE": "a nurse", "MEDICINE": "medicine",
    "PAIN": "pain", "HEADACHE": "a headache", "NAUSEA": "nausea",
    "ALLERGY": "an allergy", "INSURANCE": "insurance",

    // Transportation
    "RIDE": "a ride", "TAXI": "a taxi", "UBER": "an Uber", "LYFT": "a Lyft",
    "BUS": "the bus", "TRAIN": "the train"
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