import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  final String title;
  final bool loading;
  final String? error;
  final String emptyMessage;
  final List<Widget> children;

  const SectionCard({
    super.key,
    required this.title,
    required this.loading,
    required this.error,
    required this.emptyMessage,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (loading) {
      child = const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (error != null) {
      child = Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(error!),
      );
    } else if (children.isEmpty) {
      child = Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(emptyMessage),
      );
    } else {
      child = Column(children: children);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
