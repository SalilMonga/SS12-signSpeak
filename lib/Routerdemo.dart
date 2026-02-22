import 'package:flutter/material.dart';
import 'template_store.dart';
import 'asl_router.dart';

class RouterDemo extends StatefulWidget {
  const RouterDemo({super.key});

  @override
  State<RouterDemo> createState() => _RouterDemoState();
}

class _RouterDemoState extends State<RouterDemo> {
  bool _initialized = false;
  String _output = '';

  late TemplateStore store;
  late ASLRouter router;

  final TextEditingController _controller =
      TextEditingController(text: 'APPLE GET WANT');

  @override
  void initState() {
    super.initState();
    _initTemplates();
  }

  Future<void> _initTemplates() async {
    store = await TemplateStore.loadFromAsset('assets/templates.json');

    router = ASLRouter(
      places: {
        'BATHROOM': 'the restroom',
        'RESTROOM': 'the restroom',
        'TOILET': 'the restroom',
        'WASHROOM': 'the restroom',
        'MEN': "the men's restroom",
        'WOMEN': "the women's restroom",
        'FAMILY': 'the family restroom',

        // Entrances / exits / general areas
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

        // Navigation / movement
        'ELEVATOR': 'the elevator',
        'LIFT': 'the elevator',
        'STAIRS': 'the stairs',
        'STAIR': 'the stairs',
        'ESCALATOR': 'the escalator',
        'RAMP': 'the ramp',

        // Desks / help
        'FRONTDESK': 'the front desk',
        'FRONT-DESK': 'the front desk',
        'DESK': 'the front desk',
        'RECEPTION': 'reception',
        'CHECKIN': 'check-in',
        'CHECK-IN': 'check-in',
        'INFORMATION': 'information',
        'INFO': 'information',
        'HELPDESK': 'the help desk',
        'HELP-DESK': 'the help desk',
        'CUSTOMERSERVICE': 'customer service',
        'CUSTOMER-SERVICE': 'customer service',

        // Airport / transit style
        'GATE': 'the gate',
        'TERMINAL': 'the terminal',
        'BAGGAGE': 'baggage claim',
        'BAGGAGECLAIM': 'baggage claim',
        'BAGGAGE-CLAIM': 'baggage claim',
        'SECURITY': 'security',
        'SECURITYCHECK': 'security screening',
        'SECURITY-CHECK': 'security screening',
        'TSA': 'security screening',

        // Parking / transport
        'PARKING': 'parking',
        'GARAGE': 'the parking garage',
        'LOT': 'the parking lot',
        'BUSSTOP': 'the bus stop',
        'BUS-STOP': 'the bus stop',
        'STATION': 'the station',
        'TRAINSTATION': 'the train station',
        'TRAIN-STATION': 'the train station',
        'SUBWAY': 'the subway station',

        // Medical / services
        'CLINIC': 'the clinic',
        'HOSPITAL': 'the hospital',
        'PHARMACY': 'the pharmacy',
        'ER': 'the emergency room',
        'EMERGENCY': 'the emergency room',
        'XRAY': 'X-ray',
        'X-RAY': 'X-ray',
        'RADIOLOGY': 'radiology',
        'IMAGING': 'imaging',

        // Food / amenities
        'CAFE': 'the cafe',
        'CAFETERIA': 'the cafeteria',
        'RESTAURANT': 'the restaurant',
        'FOODCOURT': 'the food court',
        'VENDING': 'the vending machines',
        'ATM': 'the ATM',

        // Misc
        'LOSTFOUND': 'lost and found',
      },
      nouns: {
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
        'WI-FI': 'Wi-Fi',
        'INTERNET': 'internet',
        'PASSWORD': 'the password',
        'LOGIN': 'login',
        'ACCOUNT': 'my account',
        'EMAIL': 'email',
        'CHARGER': 'a charger',
        'CABLE': 'a cable',
        'BATTERY': 'battery',
        'PHONE': 'my phone',
        'CELL': 'my phone',
        'MOBILE': 'my phone',
        'LAPTOP': 'my laptop',
        'COMPUTER': 'a computer',
        'TABLET': 'a tablet',

        // Documents / payments
        'TICKET': 'a ticket',
        'PASS': 'a pass',
        'RESERVATION': 'a reservation',
        'CONFIRMATION': 'confirmation',
        'RECEIPT': 'a receipt',
        'REFUND': 'a refund',
        'FORM': 'a form',
        'DOCUMENT': 'a document',
        'PAPER': 'paperwork',
        'ID': 'my ID',
        'LICENSE': 'my ID',
        'PASSPORT': 'my passport',
        'CARD': 'my card',
        'CREDIT': 'a credit card',
        'DEBIT': 'a debit card',
        'CASH': 'cash',
        'MONEY': 'money',
        'PAYMENT': 'a payment',
        'PRICE': 'the price',
        'COST': 'the cost',
        'FEE': 'a fee',

        // Personal items
        'WALLET': 'my wallet',
        'BAG': 'my bag',
        'BACKPACK': 'my backpack',
        'PURSE': 'my purse',
        'KEY': 'my key',
        'KEYS': 'my keys',
        'WATCH': 'my watch',
        'GLASSES': 'my glasses',

        // Help / communication
        'HELP': 'help',
        'ASSIST': 'assistance',
        'ASSISTANCE': 'assistance',
        'SUPPORT': 'support',
        'INTERPRETER': 'an ASL interpreter',
        'TRANSLATOR': 'a translator',
        'CAPTION': 'captions',
        'CAPTIONS': 'captions',

        // Medical
        'DOCTOR': 'a doctor',
        'NURSE': 'a nurse',
        'MEDICINE': 'medicine',
        'PRESCRIPTION': 'a prescription',
        'INSURANCE': 'insurance',
        'PAIN': 'pain',
        'HEADACHE': 'a headache',
        'NAUSEA': 'nausea',
        'ALLERGY': 'an allergy',

        // Transport
        'RIDE': 'a ride',
        'TAXI': 'a taxi',
        'UBER': 'an Uber',
        'LYFT': 'a Lyft',
        'BUS': 'the bus',
        'TRAIN': 'the train',
      },
    );

    setState(() => _initialized = true);
    debugPrint('Templates initialized (Dart)');
  }

  void _runRouter() {
    final tokens = _controller.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w.toUpperCase())
        .toList();

    //Actually processing words and converting them to sentences
    final intentKey = router.detectIntentKey(tokens);
    final slots = router.extractSlots(tokens, intentKey);
    final template = store.pickTemplate(intentKey, slots);
    final sentence = renderTemplate(template, slots);

    setState(() => _output = sentence);
    debugPrint('Intent: $intentKey slots=$slots sentence=$sentence');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ASL Router Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_initialized ? 'Templates ready' : 'Loading templates...'),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              enabled: _initialized,
              decoration: const InputDecoration(
                labelText: 'Words (space-separated)',
                hintText: 'e.g. WHERE BATHROOM',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _runRouter(),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _initialized ? _runRouter : null,
              child: const Text('Run'),
            ),
            const SizedBox(height: 12),
            SelectableText(_output),
          ],
        ),
      ),
    );
  }
}