import 'package:flutter/material.dart';

import '../mentor/topic_info.dart';
import '../mentor/topic_texts.dart';
import '../mentor/topics.dart';
import 'strings.dart';

/// Ausführliche Erklärung zu einem Thema als aufziehbares Blatt: worum es geht, warum es passiert, wie es besser wird.
Future<void> showTopicInfo(BuildContext context, Topic topic) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (ctx) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.75,
    minChildSize: 0.4,
    maxChildSize: 0.95,
    builder: (ctx, controller) => TopicInfoView(topic: topic, controller: controller),
  ),
);

class TopicInfoView extends StatelessWidget {
  const TopicInfoView({super.key, required this.topic, this.controller});

  final Topic topic;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final info = tr.topicInfo(topic);
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
    );
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        Text(tr.topicName(topic), style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(info.what),
        heading(tr.t('Warum passiert das?', 'Why does it happen?')),
        Text(info.why),
        heading(tr.t('So machst du es besser', 'How to do better')),
        for (var i = 0; i < info.how.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text('${i + 1}', style: TextStyle(fontSize: 12, color: theme.colorScheme.onPrimaryContainer)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(info.how[i])),
              ],
            ),
          ),
        heading(tr.t('So trainierst du es', 'How to train it')),
        Text(info.practice),
        const SizedBox(height: 14),
        Text('🎯 ${tr.topicRule(topic)}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
