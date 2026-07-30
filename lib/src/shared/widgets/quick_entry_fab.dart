import 'package:flutter/material.dart';

class QuickEntryFab extends StatelessWidget {
  const QuickEntryFab({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      icon: const Icon(Icons.add),
      label: const Text('기록'),
    );
  }
}
