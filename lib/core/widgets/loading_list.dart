import 'package:flutter/material.dart';

class LoadingList extends StatelessWidget {
  const LoadingList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          child: ListTile(
            leading: Container(width: 48, height: 72, color: Colors.grey.withValues(alpha: 0.2)),
            title: Container(width: 150, height: 14, color: Colors.grey.withValues(alpha: 0.2)),
            subtitle: Container(width: 100, height: 12, color: Colors.grey.withValues(alpha: 0.2)),
          ),
        );
      },
    );
  }
}
