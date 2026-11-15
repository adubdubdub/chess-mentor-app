import 'package:flutter/material.dart';

import '../mentor/profile.dart';
import '../mentor/records.dart';
import '../mentor/topic_texts.dart';
import '../mentor/topics.dart';
import '../mentor/focus.dart';
import '../mentor/focus_keeper.dart';
import 'app_scope.dart';
import 'focus_card.dart';
import 'focus_review_page.dart';
import 'puzzle_page.dart';
import 'game_page.dart';
import 'profile_view.dart';
import 'topic_info_sheet.dart';
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
  List<FocusEntry> _history = const [];
  int _duePuzzles = 0;
  String? _aiText;
  bool _aiLoading = false;
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
    final history = [for (final f in (await store.focusHistory()).reversed) if (f.status != FocusStatus.active && f.status != FocusStatus.cancelled) f];
    if (mounted) {
      setState(() {
        _records = records;
        _focus = focus;
        _duePuzzles = due;
        _history = history;
      });
      _loadAi(records, focus);
    }
  }

  /// Persönlicher KI-Text zum Fokus (laufend) oder zum ersten Vorschlag; ohne KI oder bei Fehlern bleibt es leer.
  Future<void> _loadAi(List<GameRecord> records, FocusState focus) async {
    final scope = AppScope.of(context);
    final de = Tr.of(context).de;
    if (!scope.ai.enabled || records.isEmpty) {
      if (_aiText != null) setState(() => _aiText = null);
      return;
    }
    final profile = buildProfile(records);
    final topic = focus.active?.topic;
    final suggestions = suggestFocus(profile, lastTopic: focus.lastClosed?.topic);
    final pick = topic == null
        ? (suggestions.isEmpty ? null : suggestions.first)
        : suggestFocus(profile, count: 7).where((s) => s.topic == topic).firstOrNull;
    if (pick == null) return;
    setState(() {
      _aiLoading = true;
      _aiText = null;
    });
    final text = await scope.ai.focusText(pick, records, de: de);
    if (mounted) {
      setState(() {
        _aiText = text;
        _aiLoading = false;
      });
    }
  }

  Profile _profile(List<GameRecord> records) => buildProfile(records);

  void _openReview(FocusEntry f) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => FocusReviewPage(focus: f))).then((_) => _load());

  Widget? _historyList(Tr tr) {
    if (_history.isEmpty) return null;
    String icon(FocusStatus s) => switch (s) {
      FocusStatus.reached => '✅',
      FocusStatus.missed => '❌',
      _ => '⏱',
    };
    String date(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr.t('Frühere Fokus-Wochen', 'Previous focus weeks'), style: Theme.of(context).textTheme.titleMedium),
        for (final f in _history)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text('${icon(f.status)} ${tr.topicName(f.topic)}'),
            subtitle: Text('${date(f.startedAt)}–${date(f.endsAt.subtract(const Duration(days: 1)))}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openReview(f),
          ),
      ],
    );
  }

  Widget _card(BuildContext context, List<GameRecord> records) {
    final store = AppScope.of(context).store;
    final reminders = AppScope.of(context).reminders;
    final profile = _profile(records);
    return FocusCard(
      state: _focus,
      profile: profile,
      duePuzzles: _duePuzzles,
      aiText: _aiText,
      aiLoading: _aiLoading,
      suggestions: _focus.active != null ? const [] : suggestFocus(profile, lastTopic: _focus.lastClosed?.topic),
      onStart: (s) async {
        await store.startFocus(startFocusFrom(s, DateTime.now()));
        await reminders.rescheduleFocus();
        await _load();
      },
      onCancel: () async {
        final f = _focus.active;
        if (f != null) await store.closeFocus(f.id!, FocusStatus.cancelled, DateTime.now());
        await reminders.rescheduleFocus();
        await _load();
      },
      onReview: _openReview,
      level: AppScope.of(context).settings.level,
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
              onGame: (id) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GamePage(id: id))),
              header: records.isEmpty ? null : _card(context, records),
              footer: _historyList(tr),
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
      appBar: AppBar(
        title: Text(tr.topicName(topic)),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: tr.t('Erklärung und Tipps', 'Explanation and tips'),
            onPressed: () => showTopicInfo(context, topic),
          ),
        ],
      ),
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
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => MomentPage(moment: moment, orientation: game.analysis.color)),
              ),
            ),
        ],
      ),
    );
  }
}
