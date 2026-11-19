import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class ShareReviewPage extends StatelessWidget {
  const ShareReviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Share Review')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Preview your review card for social media', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Share.share('Check out my movie review on Movie Tracker!'),
              child: const Text('Share Review Card'),
            ),
          ],
        ),
      ),
    );
  }
}
