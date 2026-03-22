// Owner: Member 2
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VideoMonitorScreen extends ConsumerWidget {
  const VideoMonitorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'Video Call Monitor',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Press Monitor Video Call to begin passive monitoring during your call.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            SizedBox(height: 24),
            Text(
              'TODO: Implement video + audio monitor\n(Member 2)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.orange),
            ),
          ],
        ),
      ),
    );
  }
}
