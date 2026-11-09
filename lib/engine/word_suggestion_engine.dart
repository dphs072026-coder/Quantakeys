import 'dart:math' as math;

class TrieNode {
  Map<String, TrieNode> children = {};
  bool isEndOfWord = false;
}

class WordSuggestionEngine {
  final TrieNode _root = TrieNode();
  final List<String> _dictionary = [];

  WordSuggestionEngine() {
    _loadDictionary();
  }

  void _loadDictionary() {
    const words = [
      // Common Daily Words & Greetings
      'hi', 'hello', 'hey', 'thanks', 'thank you', 'thankyou', 'welcome', 'please', 'sorry', 'good', 'morning',
      'night', 'evening', 'how', 'are', 'you', 'doing', 'what', 'where', 'when', 'why', 'who',
      'is', 'it', 'the', 'and', 'but', 'or', 'so', 'can', 'will', 'do', 'go', 'get', 'see',
      'think', 'know', 'take', 'make', 'time', 'day', 'work', 'new', 'first', 'last', 'only',
      'also', 'just', 'more', 'some', 'other', 'them', 'their', 'there', 'here', 'now', 'then',
      'okay', 'cool', 'nice', 'great', 'awesome', 'yes', 'no', 'maybe', 'sure', 'fine',
      'goodbye', 'bye', 'see you', 'take care', 'talk later', 'how are you', 'thank you so much',
      'you are welcome', 'no problem', 'all right', 'excuse me', 'i am', 'i will', 'i have',
      'can you', 'please help', 'let me know', 'thank you', 'thanks a lot', 'hi there',
      'how are things', 'all the best', 'congratulations', 'good luck', 'happy birthday',
      'take care', 'stay safe', 'have a nice day', 'you are welcome', 'no worries',
      'weather', 'google', 'search', 'time', 'date', 'news', 'maps', 'video', 'music',
      'today', 'tomorrow', 'yesterday', 'this week', 'next week', 'now', 'soon',
      'what is', 'how to', 'where is', 'who is', 'why is', 'when is', 'can i',
      'i want to', 'tell me', 'show me', 'help me',

      // Basic Connectors
      'the', 'be', 'to', 'of', 'and', 'a', 'in', 'that', 'have', 'it', 'for', 'not', 'on', 'with', 
      'he', 'as', 'you', 'do', 'at', 'this', 'but', 'his', 'by', 'from', 'they', 'we', 'say', 
      'her', 'she', 'or', 'an', 'will', 'my', 'one', 'all', 'would', 'there', 'their', 'what',
      'so', 'up', 'out', 'if', 'about', 'who', 'get', 'which', 'go', 'me', 'when', 'make', 
      'can', 'like', 'time', 'no', 'just', 'him', 'know', 'take', 'people', 'into', 'year', 
      'your', 'good', 'some', 'could', 'them', 'see', 'other', 'than', 'then', 'now', 'look', 
      'only', 'come', 'its', 'over', 'think', 'also', 'back', 'after', 'use', 'two', 'how', 
      'our', 'work', 'first', 'well', 'way', 'even', 'new', 'want', 'because', 'any', 'these', 
      'give', 'day', 'most', 'us',

      // Scientific/Math Dictionary
      'science', 'math', 'physics', 'chemistry', 'scientific', 
      'quantum', 'keys', 'atom', 'molecule', 'energy', 'force', 'mass', 'gravity', 'velocity', 
      'vector', 'integral', 'derivative', 'trigonometry', 'sine', 'cosine', 'tangent', 'pi',
      'calculate', 'solve', 'formula', 'constant', 'acceleration', 'pressure', 'density'
    ];

    for (var word in words) {
      final clean = word.toLowerCase();
      _insert(clean);
      _dictionary.add(clean);
    }
  }

  void _insert(String word) {
    TrieNode current = _root;
    for (int i = 0; i < word.length; i++) {
      String char = word[i];
      current.children.putIfAbsent(char, () => TrieNode());
      current = current.children[char]!;
    }
    current.isEndOfWord = true;
  }

  List<String> getSuggestions(String prefix, {int limit = 6}) {
    if (prefix.isEmpty) {
      // Default common starters
      return ['Hi', 'Hello', 'How', 'Thanks', 'Thankyou', 'Welcome'].take(limit).toList();
    }
    
    TrieNode? current = _root;
    String cleanPrefix = prefix.toLowerCase();
    
    // 1. Direct Prefix Match (Fast)
    bool foundPrefix = true;
    for (int i = 0; i < cleanPrefix.length; i++) {
      String char = cleanPrefix[i];
      if (!current!.children.containsKey(char)) {
        foundPrefix = false;
        break;
      }
      current = current.children[char];
    }

    List<String> results = [];
    if (foundPrefix) {
      _findAllWords(current!, cleanPrefix, results, limit);
    }

    // 2. Fuzzy Match / Correction (If results are few or prefix not found)
    if (results.length < limit) {
      final fuzzy = _getFuzzyMatches(cleanPrefix, limit - results.length);
      for (var f in fuzzy) {
        if (!results.contains(f)) results.add(f);
      }
    }

    return results;
  }

  void _findAllWords(TrieNode node, String prefix, List<String> results, int limit) {
    if (results.length >= limit) return;
    if (node.isEndOfWord) results.add(prefix);

    var sortedKeys = node.children.keys.toList()..sort();
    for (var char in sortedKeys) {
      _findAllWords(node.children[char]!, prefix + char, results, limit);
      if (results.length >= limit) return;
    }
  }

  List<String> _getFuzzyMatches(String word, int limit) {
    if (word.length < 3) return [];
    
    List<_ScoredWord> scored = [];
    for (var dictWord in _dictionary) {
      int dist = _levenshtein(word, dictWord);
      // If distance is small relative to word length
      if (dist <= 2 && dist < (word.length / 2).ceil()) {
        scored.add(_ScoredWord(dictWord, dist));
      }
    }

    scored.sort((a, b) => a.score.compareTo(b.score));
    return scored.take(limit).map((e) => e.word).toList();
  }

  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        int cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = math.min(v1[j] + 1, math.min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j < t.length + 1; j++) {
        v0[j] = v1[j];
      }
    }
    return v0[t.length];
  }
}

class _ScoredWord {
  final String word;
  final int score;
  _ScoredWord(this.word, this.score);
}
