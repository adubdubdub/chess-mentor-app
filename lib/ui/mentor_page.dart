import 'package:flutter/material.dart';

import '../mentor/profile.dart';
import '../mentor/records.dart';
import '../mentor/topic_texts.dart';
import '../mentor/topics.dart';
import 'app_scope.dart';
import 'game_page.dart';
import 'profile_view.dart';
import 'strings.dart';

/// Der Mentor: Schwächenprofil über die letzten Partien.
class MentorPage extends StatefulWidget {
  const MentorPage({super.key});

  @override
  State<MentorPage> createState() => _MentorPageState();
}

class _MentorPageState extends State<MentorPage> {
  List<GameRecord>? _records;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    AppScope.of(context).store.mentorRecords().then((r) {
      if (mounted) setState(() => _records = r);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final records = _records;
    return Scaffold(
      appBar: AppBar(title: Text(tr.t('Mentor', 'Mentor'))),
      body: records == null
          ? const Center(child: CircularProgressIndicator())
          : ProfileView(
              profile: buildProfile(records),
              onTopic: (t) => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => TopicPage(topic: t, records: records)),
              ),
            ),
    );
  }
}

/// Die Fehlzüge zu einem Thema; Antippen öffnet die Partie.
class TopicPage extends StatelessWidget {
  const TopicPage({super.key, required this.topic, required this.records});

  final Topic topic;
  final List<GameRecord> records;

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final items = topicMoments(topic, records);
    return Scaffold(
      appBar: AppBar(title: Text(tr.topicName(topic))),
      body: ListView(
        children: [
          Padding(padding: const EdgeInsets.all(16), child: Text(tr.topicHint(topic))),
          for (final (:game, :moment) in items)
            ListTile(
              title: Text(
                tr.t(
                  'Zug ${moment.moveNo}: ${tr.san(moment.played)} statt ${tr.san(moment.best)}',
                  'Move ${moment.moveNo}: ${tr.san(moment.played)} instead of ${tr.san(moment.best)}',
                ),
              ),
              subtitle: Text(
                '${game.analysis.white} – ${game.analysis.black} · ${tr.phase(moment.phase)} · '
                '${tr.t('−${moment.drop.round()} Punkte', '−${moment.drop.round()} points')}',
                style: theme.textTheme.bodySmall,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GamePage(id: game.id))),
            ),
        ],
      ),
    );
  }
}
