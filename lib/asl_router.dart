class ASLRouter {
  final Map<String, String> places; // token -> pretty place
  final Map<String, String> nouns;  // token -> pretty noun

  ASLRouter({required this.places, required this.nouns});

  String detectIntentKey(List<String> tokens) {
    for (final t in tokens) {
      switch (t) {
        case 'WHERE':
          return 'askLocation';
        case 'LEFT':
        case 'RIGHT':
        case 'STRAIGHT':
        case 'UPSTAIRS':
        case 'DOWNSTAIRS':
          return 'askDirections';
        case 'INTERPRETER':
          return 'interpreter';
        case 'NEED':
          return 'need';
        case 'WANT':
          return 'want';
        case 'GET':
          return 'get';
        case 'HELP':
          return 'help';
        case 'HI':
        case 'HELLO':
        case 'HEY':
          return 'greet';
        case 'BYE':
        case 'GOODBYE':
          return 'goodbye';
        case 'THANKS':
        case 'THANK':
          return 'thanks';
        case 'SORRY':
          return 'apologize';
        case 'YES':
          return 'confirmYes';
        case 'NO':
          return 'confirmNo';
        default:
          continue;
      }
    }
    return 'unknown';
  }

  Map<String, String> extractSlots(List<String> tokens, String intentKey) {
    final slots = <String, String>{};

    const Map<String, String> places = {
  // Bathrooms
  'BATHROOM': 'the restroom',
  'RESTROOM': 'the restroom',
  'TOILET': 'the restroom',
  'WASHROOM': 'the restroom',
  'MEN': "the men's restroom",
  'WOMEN': "the women's restroom",
  'FAMILY': 'the family restroom',

  // Navigation / building
  'ENTRANCE': 'the entrance',
  'EXIT': 'the exit',
  'DOOR': 'the door',
  'LOBBY': 'the lobby',
  'HALL': 'the hallway',
  'HALLWAY': 'the hallway',
  'CORRIDOR': 'the hallway',
  'ROOM': 'the room',
  'OFFICE': 'the office',
  'BUILDING': 'the building',
  'FLOOR': 'this floor',
  'LEVEL': 'this level',

  // Moving around
  'ELEVATOR': 'the elevator',
  'LIFT': 'the elevator',
  'STAIRS': 'the stairs',
  'ESCALATOR': 'the escalator',
  'RAMP': 'the ramp',

  // Desks / help
  'FRONTDESK': 'the front desk',
  'DESK': 'the front desk',
  'RECEPTION': 'reception',
  'CHECKIN': 'check-in',
  'INFORMATION': 'information',
  'INFO': 'information',
  'HELPDESK': 'the help desk',
  'CUSTOMERSERVICE': 'customer service',
  'LOSTFOUND': 'lost and found',

  // Transit / airport-ish
  'GATE': 'the gate',
  'TERMINAL': 'the terminal',
  'BAGGAGE': 'baggage claim',
  'BAGGAGECLAIM': 'baggage claim',
  'SECURITY': 'security',
  'SECURITYCHECK': 'security screening',
  'TSA': 'security screening',

  // Parking / transport
  'PARKING': 'parking',
  'GARAGE': 'the parking garage',
  'LOT': 'the parking lot',
  'BUSSTOP': 'the bus stop',
  'STATION': 'the station',
  'TRAINSTATION': 'the train station',
  'SUBWAY': 'the subway station',

  // Medical
  'CLINIC': 'the clinic',
  'HOSPITAL': 'the hospital',
  'PHARMACY': 'the pharmacy',
  'ER': 'the emergency room',
  'EMERGENCY': 'the emergency room',

  // Food / amenities
  'CAFE': 'the cafe',
  'CAFETERIA': 'the cafeteria',
  'RESTAURANT': 'the restaurant',
  'FOODCOURT': 'the food court',
  'VENDING': 'the vending machines',
  'ATM': 'the ATM',
};

const Map<String, String> nouns = {
  // Food / drink
  'APPLE': 'apple',
  'BANANA': 'banana',
  'ORANGE': 'orange',
  'GRAPES': 'grapes',
  'WATER': 'water',
  'JUICE': 'juice',
  'SODA': 'soda',
  'COFFEE': 'coffee',
  'TEA': 'tea',
  'FOOD': 'food',
  'SNACK': 'a snack',
  'MEAL': 'a meal',

  // Tech / access
  'WIFI': 'Wi-Fi',
  'INTERNET': 'internet',
  'PASSWORD': 'the password',
  'LOGIN': 'login',
  'ACCOUNT': 'my account',
  'EMAIL': 'email',
  'CHARGER': 'a charger',
  'CABLE': 'a cable',
  'BATTERY': 'battery',
  'PHONE': 'my phone',
  'LAPTOP': 'my laptop',
  'COMPUTER': 'a computer',

  // Docs / money
  'TICKET': 'a ticket',
  'PASS': 'a pass',
  'RESERVATION': 'a reservation',
  'RECEIPT': 'a receipt',
  'REFUND': 'a refund',
  'FORM': 'a form',
  'DOCUMENT': 'a document',
  'ID': 'my ID',
  'PASSPORT': 'my passport',
  'CARD': 'my card',
  'CASH': 'cash',
  'MONEY': 'money',

  // Personal items
  'WALLET': 'my wallet',
  'BAG': 'my bag',
  'BACKPACK': 'my backpack',
  'KEYS': 'my keys',
  'GLASSES': 'my glasses',

  // Communication / help
  'HELP': 'help',
  'ASSISTANCE': 'assistance',
  'SUPPORT': 'support',
  'INTERPRETER': 'an ASL interpreter',
  'TRANSLATOR': 'a translator',
  'CAPTIONS': 'captions',

  // Medical
  'DOCTOR': 'a doctor',
  'NURSE': 'a nurse',
  'MEDICINE': 'medicine',
  'INSURANCE': 'insurance',
};

    const interrogatives = {
      'WHERE': 'Where',
      'WHAT': 'What',
      'WHO': 'Who',
      'WHEN': 'When',
      'WHY': 'Why',
      'HOW': 'How',
      'WHICH': 'Which',
    };

    const directions = {
      'LEFT': 'left',
      'RIGHT': 'right',
      'STRAIGHT': 'straight',
      'FORWARD': 'straight',
      'UPSTAIRS': 'upstairs',
      'DOWNSTAIRS': 'downstairs',
      'UP': 'up',
      'DOWN': 'down',
    };

    // INTERROGATIVE
    for (final t in tokens) {
      final q = interrogatives[t];
      if (q != null) {
        slots['INTERROGATIVE'] = q;
        break;
      }
    }

    // DIRECTION
    for (final t in tokens) {
      final d = directions[t];
      if (d != null) {
        slots['DIRECTION'] = d;
        break;
      }
    }

    // PLACE (from vocab)
    for (final t in tokens) {
      final p = places[t];
      if (p != null) {
        slots['PLACE'] = p;
        break;
      }
    }

    // NOUN (from vocab)
    for (final t in tokens) {
      final n = nouns[t];
      if (n != null) {
        slots['NOUN'] = n;
        break;
      }
    }

    // NAME patterns: NAME JOHN / MY NAME JOHN
    final iName = tokens.indexOf('NAME');
    if (iName != -1 && iName + 1 < tokens.length) {
      slots['NAME'] = _pretty(tokens[iName + 1]);
    } else {
      final iMy = _findSequence(tokens, ['MY', 'NAME']);
      if (iMy != -1 && iMy + 2 < tokens.length) {
        slots['NAME'] = _pretty(tokens[iMy + 2]);
      }
    }

    // Fallback content tokens
    const signal = {
      'WHERE','WHAT','WHO','WHEN','WHY','HOW','WHICH',
      'WANT','NEED','GET','HELP','INTERPRETER',
      'HI','HELLO','HEY','BYE','GOODBYE','THANKS','THANK','SORRY',
      'YES','NO',
      'LEFT','RIGHT','STRAIGHT','FORWARD','UP','DOWN','UPSTAIRS','DOWNSTAIRS'
    };
    const stop = {'I','ME','MY','YOU','YOUR','WE','THE','A','AN','TO','FOR','WITH','PLEASE','PLS','NOW'};

    final content = tokens.where((t) {
      return !signal.contains(t) &&
          !stop.contains(t) &&
          !interrogatives.containsKey(t) &&
          !directions.containsKey(t) &&
          !places.containsKey(t) &&
          !nouns.containsKey(t);
    }).toList();

    // If asking location/directions and PLACE missing, treat first leftover as a place
    if ((intentKey == 'askLocation' || intentKey == 'askDirections') &&
        !slots.containsKey('PLACE') &&
        content.isNotEmpty) {
      slots['PLACE'] = 'the ${content.first.toLowerCase()}';
    }

    // If NOUN missing, use first leftover as noun (or join 2 words)
    if (!slots.containsKey('NOUN') && content.isNotEmpty) {
      slots['NOUN'] = (content.length >= 2)
          ? '${content[0].toLowerCase()} ${content[1].toLowerCase()}'
          : content.first.toLowerCase();
    }

    return slots;
  }

  static String _pretty(String token) {
    final lower = token.toLowerCase();
    if (lower.isEmpty) return lower;
    return lower[0].toUpperCase() + lower.substring(1);
  }

  static int _findSequence(List<String> tokens, List<String> seq) {
    if (seq.isEmpty || tokens.length < seq.length) return -1;
    for (int i = 0; i <= tokens.length - seq.length; i++) {
      bool ok = true;
      for (int j = 0; j < seq.length; j++) {
        if (tokens[i + j] != seq[j]) {
          ok = false;
          break;
        }
      }
      if (ok) return i;
    }
    return -1;
  }
}