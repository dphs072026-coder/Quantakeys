import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/calculation_history_provider.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final history = context.watch<CalculationHistoryProvider>();
    
    // Group by date
    final Map<String, List<dynamic>> grouped = {};
    for (var item in history.items) {
      final dateKey = DateFormat('yyyy-MM-dd').format(item.timestamp);
      if (!grouped.containsKey(dateKey)) grouped[dateKey] = [];
      grouped[dateKey]!.add(item);
    }
    
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculation History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => history.clearHistory(),
          ),
        ],
      ),
      body: history.items.isEmpty
          ? const Center(child: Text('No history yet.'))
          : ListView.builder(
              itemCount: sortedDates.length,
              itemBuilder: (context, dateIndex) {
                final dateKey = sortedDates[dateIndex];
                final dayItems = grouped[dateKey]!;
                final dateLabel = DateFormat('EEEE, MMM dd').format(dayItems.first.timestamp);
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(dateLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    ),
                    ...dayItems.map((item) => ListTile(
                      title: Text(item.result, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      subtitle: Text(item.input),
                      trailing: Text(DateFormat('HH:mm').format(item.timestamp)),
                    )),
                  ],
                );
              },
            ),
    );
  }
}
