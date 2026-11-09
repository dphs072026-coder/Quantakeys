import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class UsageSlider extends StatelessWidget {
  const UsageSlider({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Daily AI Usage', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (settings.dailyUsageCount / settings.dailyUsageLimit).clamp(0.0, 1.0),
            backgroundColor: Colors.grey.withValues(alpha: 0.2),
            color: settings.dailyUsageCount >= settings.dailyUsageLimit ? Colors.red : Colors.blue,
          ),
          const SizedBox(height: 8),
          Text(
            '${settings.dailyUsageCount} / ${settings.dailyUsageLimit} daily free cloud AI requests used today.',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
