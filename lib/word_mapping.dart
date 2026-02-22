//Maps to categorise words and get respective sentnces based on 
//type of word

Map<String, String> wordsToCategory = {
  "HELLO": "greetings_polite",
  "GOODBYE": "greetings_polite",
  "PLEASE": "greetings_polite",
  "THANK_YOU": "greetings_polite",
  "SORRY": "greetings_polite",

  "YES": "yes_no_negation",
  "NO": "yes_no_negation",
  "NOT": "yes_no_negation",
  "DONT": "yes_no_negation",
  "NEVER": "yes_no_negation",
  "NONE": "yes_no_negation",
  "CANNOT": "yes_no_negation",

  "I": "pronouns_people",
  "YOU": "pronouns_people",
  "HE": "pronouns_people",
  "SHE": "pronouns_people",
  "WE": "pronouns_people",
  "THEY": "pronouns_people",
  "PEOPLE": "pronouns_people",
  "FRIEND": "pronouns_people",
  "FAMILY": "pronouns_people",
  "MOM": "pronouns_people",
  "DAD": "pronouns_people",
  "woman": "pronouns_people",
  "hearing": "pronouns_people",
  "deaf": "pronouns_people",

  "THIS": "demonstratives_location",
  "THAT": "demonstratives_location",
  "HERE": "demonstratives_location",
  "THERE": "demonstratives_location",

  "WHO": "questions_wh",
  "WHAT": "questions_wh",
  "WHERE": "questions_wh",
  "WHEN": "questions_wh",
  "WHY": "questions_wh",
  "HOW": "questions_wh",

  "NAME": "identity_meeting",
  "MEET": "identity_meeting",

  "WANT": "wants_needs",
  "NEED": "wants_needs",
  "HELP": "wants_needs",

  "KNOW": "thinking_knowing",
  "THINK": "thinking_knowing",
  "UNDERSTAND": "thinking_knowing",
  "oh_i_see": "thinking_knowing",

  "CAN": "abilities",

  "GO": "verbs_actions",
  "COME": "verbs_actions",
  "GIVE": "verbs_actions",
  "TAKE": "verbs_actions",
  "ASK": "verbs_actions",
  "TELL": "verbs_actions",
  "SAY": "verbs_actions",
  "SEE": "verbs_actions",
  "LOOK": "verbs_actions",
  "look_at": "verbs_actions",
  "WATCH": "verbs_actions",
  "EAT": "verbs_actions",
  "DRINK": "verbs_actions",
  "SLEEP": "verbs_actions",
  "WORK": "verbs_actions",
  "PLAY": "verbs_actions",
  "LEARN": "verbs_actions",
  "READ": "verbs_actions",
  "LIVE": "verbs_actions",
  "HAVE": "verbs_actions",
  "MAKE": "verbs_actions",
  "throw": "verbs_actions",
  "FINISH": "verbs_actions",
  "START": "verbs_actions",

  "NOW": "time_words",
  "TODAY": "time_words",
  "TOMORROW": "time_words",
  "YESTERDAY": "time_words",
  "MORNING": "time_words",
  "NIGHT": "time_words",
  "BEFORE": "time_words",
  "AFTER": "time_words",
  "LATER": "time_words",
  "TIME": "time_words",

  "LIKE": "feelings_opinions",
  "LOVE": "feelings_opinions",
  "HAPPY": "feelings_opinions",
  "SAD": "feelings_opinions",
  "GOOD": "feelings_opinions",
  "BAD": "feelings_opinions",

  "SAME": "comparisons",
  "DIFFERENT": "comparisons",
  "SAME_AS": "comparisons",
  "same_as": "comparisons",

  "AND": "connectors",
  "OR": "connectors",
  "BUT": "connectors",
  "BECAUSE": "connectors",
  "IF": "connectors",
  "WITH": "connectors",

  "SCHOOL": "objects_places",
  "HOME": "objects_places",
  "CAR": "objects_places",
  "PHONE": "objects_places",
  "FOOD": "objects_places",
  "WATER": "objects_places",
  "BATHROOM": "objects_places",
  "MONEY": "objects_places",
  "lights": "objects_places",
  "shirts": "objects_places",
  "hair": "objects_places",

  "color": "colors",
  "red": "colors",
  "blue": "colors",
  "green": "colors",
  "yellow": "colors",
  "purple": "colors",

  "BIG": "size",
  "SMALL": "size",

  "MY": "possessives",
  "YOUR": "possessives",
};

//Map category to sentence
Map<String, List<String>> SentenceMappings = {
    "greetings_polite": [
    "Hello, {X}!",
    "Goodbye, {X}.",
    "Please {X}.",
    "Thank you, {X}.",
    "I'm sorry, {X}.",
  ],

  "yes_no_negation": [
    "No, {X}.",
    "I do not {X}.",
    "I will never {X}.",
    "I can't {X}.",
  ],

  "pronouns_people": [
    "I am {X}",
    "He is {X}.",
    "She is {X}.",
    "We are {X}",
    "They are {X}",
    "{X} is my friend.",
    "{X} is my family.",
    "{X} is my mom.",
    "{X} is my dad.",
    "{X} is deaf.",
  ],

  "demonstratives_location": [
    "This is {X}",
    "That is {X}",
    "{X} is good.",
  ],

  "questions_wh": [
    "Who is {X}?",
    "What is {X}?",
    "Where is {X}?",
    "When is {X}?",
    "Why is {X} {Y}?",
    "How is {X}?",
  ],

  "identity_meeting": [
    "My name is {X}.",
    "Nice to meet you, {X}.",
  ],

  "wants_needs": [
    "I want {X}.",
    "I need {X}.",
    "Please help me with {X}.",
  ],

  "thinking_knowing": [
    "I know {X}.",
    "I think {X}.",
    "I understand {X}.",
    "Oh, I see.",
  ],

  "abilities": [
    "I can {X}.",
    "I can't {X}.",
  ],

  "verbs_actions": [
    "I will go to {X}.",
    "Can you come to {X}?",
    "I can give you {X}.",
    "I asked {X}",
    "{X} told me",
    "I see {X}",
    "Look, {X}!",
    "Lets watch {X}!",
    "I will eat a {X}",
    "Did {X} go to sleep?"
    "Work was {X}",
    "I want to play with {X}",
    "Where did you learn to {X}?", 
    "Did you read {X}?",
    "Where do you live?",
    "I have {X}",
    "Did you make the {X}?",
    "Can you throw away the {X}?",
    "Did you finish?",
    "Did you start?",
  ],

  "time_words": [
    "I have to {X} now",
    "I can {X} today",
    "{X} is tomorrow",
    "I did {X} yesterday.",
    "This morning was {X}!",
    "I did {X} last night",
    "Who was before {X}",
    "I was after {X}",
    "I will do {X} later",
    "What time is {X}?"
  ],

  "feelings_opinions": [
    "{X} is happy",
    "{X} is sad",
    "I like {X}.",
    "I love {X}.",
    "{X} is good.",
    "{X} is bad",
  ],

  "comparisons": [
    "This is the same as {X}.",
    "This is different from {X}.",
  ],

//cleaned up until here
  "connectors": [
    "I want {X} and {Y}.",
    "Do you want {X} or {Y}?",
    "I want {X}, but I need {Y}.",
    "I am {X} because {Y}.",
    "If {X}, we will go.",
    "Come with {X}.",
  ],

  "objects_places": [
    "School is over at {X}",
    "I am going to {X}.",
    "Where is the {X}?",
    "I have {X}.",
    "I need the {X}.",
  ],

  "colors": [
    "The color is {X}.",
    "My shirt is {X}.",
    "Her hair is {X}.",
    "The lights are {X}.",
  ],

  "size": [
    "The {X} is big.",
    "The {X} is small.",
  ],

  "possessives": [
    "{X} phone is here.",
    "{X} car is there.",
    "{X} family is here.",
  ],
};

//function which accepts a topic word and gives back
//a template for a sentence
String? makeSentence(String topic, Map<String, String> wordsToCategory, Map<String, List<String>> SentenceMappings) {
  try {
    // Get the category for the topic word
    String? category = wordsToCategory[topic];

    if (category == null) {
      print("Could not find topic related to word");
      return null;
    }

    // Get the list of sentences for the category
    List<String>? categorySentences = SentenceMappings[category];

    if (categorySentences == null) {
      print("No sentences found for category: $category");
      return null;
    }

    // Find the first sentence that contains the placeholder
    for (var sentence in categorySentences) {
      if (sentence.contains(topic)) {
        return sentence;
      }
    }

    print('Could not find appropriate sentence in category');
    return null;
  } catch (e) {
    print("An error occurred: $e");
    return null;
  }
}
void main(){
    print(makeSentence("TOMORROW", wordsToCategory, SentenceMappings));
}