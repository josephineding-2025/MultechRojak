// Owner: Member 3
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flag_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'Community Flagging',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Check if a profile has been reported, or flag a confirmed scammer.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            SizedBox(height: 24),
            Text(
              'TODO: Implement flag/check UI\n(Member 3)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.orange),
            ),
          ],
        ),
      ),
    );
  }
}
