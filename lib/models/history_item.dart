class HistoryItem {
  final String id;
  final String input;
  final String result;
  final DateTime timestamp;

  HistoryItem({
    required this.id,
    required this.input,
    required this.result,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'input': input,
        'result': result,
        'timestamp': timestamp.toIso8601String(),
      };

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
        id: json['id'],
        input: json['input'],
        result: json['result'],
        timestamp: DateTime.parse(json['timestamp']),
      );
}
