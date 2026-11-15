import 'package:flutter/material.dart';

import '../mentor/focus.dart';
import '../mentor/focus_review.dart';
import '../mentor/profile.dart';
import '../mentor/records.dart';
import 'app_scope.dart';
import 'focus_review_view.dart';
import 'game_page.dart';
import 'strings.dart';

/// Rückblick auf einen beendeten Wochenfokus.
class FocusReviewPage extends StatefulWidget {
  const FocusReviewPage({super.key, required this.focus});

  final FocusEntry focus;

  @override
  State<FocusReviewPage> createState() => _FocusReviewPageState();
}

class _FocusReviewPageState extends State<FocusReviewPage> {
  FocusReview? _review;
  FocusSuggestion? _next;
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
    final records = await store.mentorRecords();
    final stats = await store.focusPuzzleStats(widget.focus);
    final profile = buildProfile(records);
    final suggestions = suggestFocus(profile, lastTopic: widget.focus.topic);
    if (!mounted) return;
    setState(() {
      _review = buildFocusReview(widget.focus, records, puzzleAttempts: stats.attempts, puzzleClean: stats.clean);
      _next = suggestions.isEmpty ? null : suggestions.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final r = _review;
    return Scaffold(
      appBar: AppBar(title: Text(tr.t('Wochenrückblick', 'Weekly review'))),
      body: r == null
          ? const Center(child: CircularProgressIndicator())
          : FocusReviewView(
              review: r,
              next: _next,
              onGame: (id) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GamePage(id: id))),
              onMoment: (GameRecord g, m) => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => MomentPage(moment: m, orientation: g.analysis.color)),
              ),
              onNew: () => Navigator.of(context).pop(),
            ),
    );
  }
}
