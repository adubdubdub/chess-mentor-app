import 'package:flutter/material.dart';

import '../mentor/profile.dart';
import '../mentor/records.dart';
import '../mentor/topic_texts.dart';
import '../mentor/topics.dart';
import '../mentor/focus.dart';
import '../mentor/focus_keeper.dart';
import 'app_scope.dart';
import 'focus_card.dart';
import 'puzzle_page.dart';
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
  FocusState _focus = const FocusState();
  int _duePuzzles = 0;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    final store = AppScope.of(context).store;
    final focus = await FocusKeeper(store).refresh();
    final records = await store.mentorRecords();
    final due = focus.active == null ? 0 : await store.dueFocusPuzzles(focus.active!.topic);
    if (mounted) {
      setState(() {
        _records = records;
        _focus = focus;
        _duePuzzles = due;
      });
    }
  }

  Profile _profile(List<GameRecord> records) => buildProfile(records);

  Widget _card(BuildContext context, List<GameRecord> records) {
    final store = AppScope.of(context).store;
    final profile = _profile(records);
    return FocusCard(
      state: _focus,
      profile: profile,
      duePuzzles: _duePuzzles,
      suggestions: _focus.active != null ? const [] : suggestFocus(profile, lastTopic: _focus.lastClosed?.topic),
      onStart: (s) async {
        await store.startFocus(startFocusFrom(s, DateTime.now()));
        await _load();
      },
      onCancel: () async {
        final f = _focus.active;
        if (f != null) await store.closeFocus(f.id!, FocusStatus.cancelled, DateTime.now());
        await _load();
      },
      onPractice: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PuzzlePage())).then((_) => _load()),
    );
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
              profile: _profile(records),
              header: records.isEmpty ? null : _card(context, records),
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
