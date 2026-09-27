import 'package:flutter/material.dart';

import '../models/book.dart';
import '../services/library_repository.dart';
import '../widgets/book_cover.dart';
import 'epub_reader_screen.dart';
import 'pdf_reader_screen.dart';

enum _SortMode {
  recent('Letti di recente'),
  added('Aggiunti di recente'),
  title('Titolo');

  const _SortMode(this.label);
  final String label;
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.repository});

  final LibraryRepository repository;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  _SortMode _sort = _SortMode.recent;
  String _filter = '';
  bool _searching = false;
  bool _importing = false;

  LibraryRepository get _repo => widget.repository;

  List<Book> _visibleBooks() {
    final q = _filter.trim().toLowerCase();
    final list = _repo.books
        .where((b) => q.isEmpty || b.title.toLowerCase().contains(q) || (b.author?.toLowerCase().contains(q) ?? false))
        .toList();
    switch (_sort) {
      case _SortMode.recent:
        list.sort((a, b) => (b.lastOpenedAt ?? b.addedAt).compareTo(a.lastOpenedAt ?? a.addedAt));
      case _SortMode.added:
        list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      case _SortMode.title:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
    return list;
  }

  Future<void> _import() async {
    setState(() => _importing = true);
    try {
      final added = await _repo.pickAndImport();
      if (!mounted || added.isEmpty) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(added.length == 1 ? 'Aggiunto "${added.first.title}"' : 'Aggiunti ${added.length} libri'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Importazione non riuscita: $e')));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _open(Book book) async {
    book.lastOpenedAt = DateTime.now();
    await _repo.update(book);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => switch (book.format) {
          BookFormat.epub => EpubReaderScreen(repository: _repo, book: book),
          BookFormat.pdf => PdfReaderScreen(repository: _repo, book: book),
        },
      ),
    );
  }

  Future<void> _showBookActions(Book book) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(book.author ?? book.format.name.toUpperCase()),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Modifica titolo e autore'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.restart_alt),
              title: const Text('Azzera avanzamento'),
              onTap: () => Navigator.pop(context, 'reset'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
              title: const Text('Rimuovi dalla libreria'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'edit':
        await _editMetadata(book);
      case 'reset':
        book
          ..progress = 0
          ..lastPosition = null;
        await _repo.update(book);
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Rimuovere il libro?'),
            content: Text('"${book.title}" verrà eliminato insieme a evidenziazioni e segnalibri.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Rimuovi')),
            ],
          ),
        );
        if (ok == true) await _repo.delete(book);
    }
  }

  Future<void> _editMetadata(Book book) async {
    final titleCtrl = TextEditingController(text: book.title);
    final authorCtrl = TextEditingController(text: book.author ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dettagli libro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Titolo'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: authorCtrl,
              decoration: const InputDecoration(labelText: 'Autore'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salva')),
        ],
      ),
    );
    if (ok == true) {
      if (titleCtrl.text.trim().isNotEmpty) book.title = titleCtrl.text.trim();
      book.author = authorCtrl.text.trim().isEmpty ? null : authorCtrl.text.trim();
      await _repo.update(book);
    }
    titleCtrl.dispose();
    authorCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _repo,
      builder: (context, _) {
        final books = _visibleBooks();
        return Scaffold(
          appBar: AppBar(
            title: _searching
                ? TextField(
                    autofocus: true,
                    decoration: const InputDecoration(hintText: 'Cerca titolo o autore', border: InputBorder.none),
                    onChanged: (v) => setState(() => _filter = v),
                  )
                : const Text('BFP-eReader'),
            actions: [
              IconButton(
                tooltip: _searching ? 'Chiudi ricerca' : 'Cerca',
                icon: Icon(_searching ? Icons.close : Icons.search),
                onPressed: () => setState(() {
                  _searching = !_searching;
                  if (!_searching) _filter = '';
                }),
              ),
              PopupMenuButton<_SortMode>(
                tooltip: 'Ordina',
                icon: const Icon(Icons.sort),
                initialValue: _sort,
                onSelected: (v) => setState(() => _sort = v),
                itemBuilder: (_) => [for (final m in _SortMode.values) PopupMenuItem(value: m, child: Text(m.label))],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _importing ? null : _import,
            icon: _importing
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add),
            label: const Text('Importa'),
          ),
          body: _repo.books.isEmpty
              ? _EmptyLibrary(onImport: _import)
              : books.isEmpty
              ? const Center(child: Text('Nessun libro corrisponde alla ricerca'))
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.52,
                  ),
                  itemCount: books.length,
                  itemBuilder: (context, i) => _BookTile(
                    book: books[i],
                    onTap: () => _open(books[i]),
                    onLongPress: () => _showBookActions(books[i]),
                  ),
                ),
        );
      },
    );
  }
}

class _BookTile extends StatelessWidget {
  const _BookTile({required this.book, required this.onTap, required this.onLongPress});

  final Book book;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: BookCover(book: book)),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: book.progress, minHeight: 3, borderRadius: BorderRadius.circular(2)),
          const SizedBox(height: 6),
          Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
          Text(
            '${book.author ?? book.format.name.toUpperCase()} · ${(book.progress * 100).round()}%',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('La libreria è vuota', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Importa file EPUB o PDF per iniziare a leggere.', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('Importa libri'),
            ),
          ],
        ),
      ),
    );
  }
}
