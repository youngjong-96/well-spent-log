import 'package:flutter/material.dart';

Future<bool?> showHiddenItemReuseDialog(
  BuildContext context, {
  required String message,
}) => showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('다시 사용할까요?'),
    content: Text(message),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('새로 만들기'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text('다시 사용'),
      ),
    ],
  ),
);

class HiddenItemsSection extends StatelessWidget {
  const HiddenItemsSection({
    super.key,
    required this.title,
    required this.items,
  });

  final String title;
  final List<HiddenItemTile> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        const Divider(height: 24),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        ...items,
      ],
    );
  }
}

class HiddenItemTile extends StatelessWidget {
  const HiddenItemTile({
    super.key,
    required this.leading,
    required this.name,
    required this.transactionCount,
    required this.onRestore,
  });

  final Widget leading;
  final String name;
  final int transactionCount;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: leading,
    title: Text(name),
    subtitle: Text('기존 내역 $transactionCount건'),
    trailing: TextButton(onPressed: onRestore, child: const Text('다시 사용')),
  );
}
