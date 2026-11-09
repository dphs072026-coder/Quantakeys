import 'package:flutter/material.dart';

class InstructionPage extends StatelessWidget {
  const InstructionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('How to Use QuantaKeys'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              context,
              '1. Setup & Activation',
              'QuantaKeys must be enabled in your system settings to be used in other applications.',
              Icons.settings_suggest,
              [
                'Android: Settings > System > Languages > On-screen keyboard > Manage keyboards > Enable QuantaKeys.',
                'Switching: While typing, swipe down or tap the keyboard icon to switch to the QuantaKeys Scientific Agent.',
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              '2. The Magic Tool (Magic Wand)',
              'Our sophisticated Hybrid Agent performs two tasks with one single icon on the top bar.',
              Icons.auto_fix_high,
              [
                'Solve: Select a complex equation (e.g. diff(sin(x))) and tap the Wand to see the solution in the suggestion bar.',
                'Polish: Select scrambled or grammatically weak text (e.g. "what doing you") and tap the Wand. The Agent will instantly replace it with a professional, corrected version.',
                'Smart Detection: The Wand automatically distinguishes between mathematical formulas and conversational text.',
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              '3. Scientific Solving',
              'QuantaKeys uses a deterministic NLP interpreter for lightning-fast, offline calculations.',
              Icons.calculate,
              [
                'Calculus: Symbolic differentiation (diff) and numerical integration (int).',
                'Physics & Chemistry: Formula variable extraction and atomic mass calculations.',
                'Live Suggestions: Watch solutions appear in real-time as you type your formulas.',
                'Smart Append: Choose in Settings whether to keep the question or replace it with just the answer.',
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              '4. Daily Communication',
              'Beyond science, QuantaKeys is your professional daily driver.',
              Icons.chat_bubble_outline,
              [
                'Starter Suggestions: Quick access to "Hi", "Hello", "Thanks", and other common greetings.',
                'Conversational Logic: Intelligent word suggestions for faster daily typing.',
                'Monospace Precision: A "Scientific Instrument" aesthetic for both math and messaging.',
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              '5. Advanced Interaction',
              'The keyboard adapts to your device and professional workflow.',
              Icons.touch_app,
              [
                'Desktop Dragging: On Windows, simply tap and drag the Suggestion Bar to move the keyboard anywhere on your screen.',
                'Contextual Highlighting: Related keys (like exponents or parentheses) subtly glow to guide your typing intent.',
                'Custom Layouts: Create and manage your own scientific keypads for specific research fields.',
              ],
            ),
            const SizedBox(height: 32),
            Center(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.verified),
                label: const Text('Start Solved Typing'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String description, IconData icon, List<String> bullets) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.blue, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          description,
          style: TextStyle(
            fontSize: 15, 
            color: isDark ? Colors.white70 : Colors.black87,
            height: 1.4
          ),
        ),
        if (bullets.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...bullets.map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6.0, right: 10.0),
                  child: CircleAvatar(radius: 3, backgroundColor: Colors.blue),
                ),
                Expanded(
                  child: Text(
                    b, 
                    style: TextStyle(
                      fontSize: 14, 
                      color: isDark ? Colors.white60 : Colors.black54,
                    )
                  )
                ),
              ],
            ),
          )),
        ],
      ],
    );
  }
}
