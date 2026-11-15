import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'strings.dart';

/// Online-Konten: Benutzernamen für Lichess und Chess.com, Abruf neuer Partien.
class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  late final TextEditingController _lichess;
  late final TextEditingController _chesscom;
  String? _message;
  bool _inited = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;
    final s = AppScope.of(context).settings;
    _lichess = TextEditingController(text: s.lichessUser);
    _chesscom = TextEditingController(text: s.chesscomUser);
  }

  @override
  void dispose() {
    _lichess.dispose();
    _chesscom.dispose();
    super.dispose();
  }

  void _save() {
    final s = AppScope.of(context).settings;
    if (s.lichessUser != _lichess.text.trim()) s.lichessSince = null;
    if (s.chesscomUser != _chesscom.text.trim()) s.chesscomSince = null;
    s.lichessUser = _lichess.text;
    s.chesscomUser = _chesscom.text;
  }

  Future<void> _fetch() async {
    final tr = Tr.of(context);
    _save();
    final fetch = AppScope.of(context).fetch;
    setState(() => _message = null);
    final r = await fetch.fetchNow();
    if (!mounted) return;
    setState(() {
      _message = [
        if (r.added > 0 || !r.hasErrors)
          tr.t(
            '${r.added} neue Partien geholt${r.known > 0 ? ', ${r.known} schon vorhanden' : ''}.',
            '${r.added} new games fetched${r.known > 0 ? ', ${r.known} already there' : ''}.',
          ),
        ...r.errors,
      ].join('\n');
    });
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final scope = AppScope.of(context);
    final settings = scope.settings;
    return Scaffold(
      appBar: AppBar(title: Text(tr.t('Online-Konten', 'Online accounts'))),
      body: ListenableBuilder(
        listenable: Listenable.merge([settings, scope.fetch]),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              tr.t(
                'Neue beendete Partien werden über die öffentlichen Schnittstellen geholt. Dafür brauchst du keinen '
                    'Schlüssel und kein Passwort, nur den Benutzernamen.',
                'New finished games are fetched through the public APIs. You need no key or password, only your user name.',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _lichess,
              autocorrect: false,
              decoration: InputDecoration(labelText: tr.t('Lichess-Benutzername', 'Lichess user name'), border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _chesscom,
              autocorrect: false,
              decoration: InputDecoration(labelText: tr.t('Chess.com-Benutzername', 'Chess.com user name'), border: const OutlineInputBorder()),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr.t('Beim Start abrufen', 'Fetch on start')),
              subtitle: Text(tr.t('Höchstens einmal am Tag', 'At most once a day')),
              value: settings.autoFetch,
              onChanged: (v) => settings.autoFetch = v,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: scope.fetch.busy ? null : _fetch,
                  icon: const Icon(Icons.cloud_download),
                  label: Text(tr.t('Jetzt abrufen', 'Fetch now')),
                ),
                if (scope.fetch.busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            if (_message != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_message!)),
            if (settings.lastFetch != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  tr.t('Zuletzt abgerufen: ${settings.lastFetch!.toLocal().toString().substring(0, 16)}', 'Last fetched: ${settings.lastFetch!.toLocal().toString().substring(0, 16)}'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              tr.t(
                'Beim ersten Abruf werden die Partien der letzten 7 Tage geholt, danach nur neue (höchstens 30 je Abruf). '
                    'Neue Partien werden automatisch analysiert.',
                'The first fetch gets the games of the last 7 days, afterwards only new ones (at most 30 per fetch). '
                    'New games are analysed automatically.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
