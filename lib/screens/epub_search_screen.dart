import 'package:flutter/material.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';

/// Ricerca full-text nel libro. Ritorna (pop) il CFI del risultato scelto.
class EpubSearchScreen extends StatefulWidget {
  const EpubSearchScreen({super.key, required this.controller});

  final EpubController controller;

  @override
  State<EpubSearchScreen> createState() => _EpubSearchScreenState();
}

class _EpubSearchScreenState extends State<EpubSearchScreen> {
  List<EpubSearchResult> _results = [];
  bool _busy = false;
  String? _error;
  String _lastQuery = '';

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _lastQuery = q;
    });
    try {
      final res = await widget.controller.search(query: q);
      if (mounted) setState(() => _results = res);
    } catch (e) {
      if (mounted) setState(() => _error = 'Ricerca non riuscita: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(hintText: 'Cerca nel libro', border: InputBorder.none),
          onSubmitted: _search,
        ),
      ),
      body: Builder(
        builder: (context) {
          if (_busy) return const Center(child: CircularProgressIndicator());
          if (_error != null) return Center(child: Text(_error!));
          if (_lastQuery.isNotEmpty && _results.isEmpty) {
            return Center(child: Text('Nessun risultato per "$_lastQuery"'));
          }
          return ListView.separated(
            itemCount: _results.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = _results[i];
              return ListTile(
                title: Text(r.excerpt.trim(), maxLines: 3, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.pop(context, r.cfi),
              );
            },
          );
        },
      ),
    );
  }
}
