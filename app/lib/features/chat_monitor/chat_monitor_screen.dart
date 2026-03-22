// Owner: Member 2
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatMonitorScreen extends ConsumerWidget {
  const ChatMonitorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'Chat Monitor',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Press Scan Chat, scroll through the conversation, then press Analyze.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            SizedBox(height: 24),
            Text(
              'TODO: Implement scan/analyze flow\n(Member 2)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.orange),
            ),
          ],
        ),
      ),
    );
  }
}
