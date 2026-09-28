import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../models/book.dart';
import '../models/reader_settings.dart';
import '../services/library_repository.dart';
import '../widgets/reader_settings_sheet.dart';

/// Matrice di inversione colori per la lettura notturna dei PDF.
const _invertMatrix = <double>[
  -1, 0, 0, 0, 255, //
  0, -1, 0, 0, 255, //
  0, 0, -1, 0, 255, //
  0, 0, 0, 1, 0, //
];

class PdfReaderScreen extends StatefulWidget {
  const PdfReaderScreen({super.key, required this.repository, required this.book});

  final LibraryRepository repository;
  final Book book;

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  final _controller = PdfViewerController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  late ReaderSettings _settings = widget.repository.settings;
  late final int _initialPage = int.tryParse(widget.book.lastPosition ?? '') ?? 1;

  int _page = 1;
  int _pageCount = 0;
  List<PdfOutlineNode> _outline = [];

  Book get _book => widget.book;

  bool get _invert => _settings.theme == ReaderThemeMode.dark || _settings.theme == ReaderThemeMode.black;

  void _onViewerReady(PdfDocument document, PdfViewerController controller) {
    setState(() {
      _pageCount = document.pages.length;
      _page = controller.pageNumber ?? _initialPage;
    });
    document
        .loadOutline()
        .then((o) {
          if (mounted) setState(() => _outline = o);
        })
        .catchError((Object _) {});
  }

  void _onPageChanged(int? page) {
    if (page == null || _pageCount == 0) return;
    setState(() => _page = page);
    _book
      ..lastPosition = '$page'
      ..progress = _pageCount <= 1 ? 1 : (page - 1) / (_pageCount - 1);
    unawaited(widget.repository.update(_book, notify: false));
  }

  void _goTo(int page) {
    if (_pageCount == 0) return;
    _controller.goToPage(pageNumber: page.clamp(1, _pageCount));
    _scaffoldKey.currentState?.closeDrawer();
  }

  Future<void> _askPage() async {
    final ctrl = TextEditingController(text: '$_page');
    final page = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vai a pagina'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(helperText: '1 – $_pageCount'),
          onSubmitted: (v) => Navigator.pop(context, int.tryParse(v)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(context, int.tryParse(ctrl.text)), child: const Text('Vai')),
        ],
      ),
    );
    ctrl.dispose();
    if (page != null) _goTo(page);
  }

  Future<void> _toggleBookmark() async {
    final pos = '$_page';
    final existing = _book.bookmarks.where((b) => b.position == pos).firstOrNull;
    if (existing != null) {
      _book.bookmarks.remove(existing);
    } else {
      _book.bookmarks.add(
        Bookmark(position: pos, label: 'Pagina $_page', progress: _book.progress, createdAt: DateTime.now()),
      );
      _book.bookmarks.sort((a, b) => a.progress.compareTo(b.progress));
    }
    await widget.repository.update(_book, notify: false);
    setState(() {});
  }

  void _applySettings(ReaderSettings s) {
    setState(() => _settings = s);
    unawaited(widget.repository.updateSettings(s));
  }

  List<Widget> _outlineTiles(List<PdfOutlineNode> nodes, int depth) => [
    for (final n in nodes) ...[
      ListTile(
        dense: depth > 0,
        contentPadding: EdgeInsets.only(left: 16.0 + depth * 16, right: 16),
        title: Text(n.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: n.dest != null ? Text('${n.dest!.pageNumber}') : null,
        onTap: n.dest != null ? () => _goTo(n.dest!.pageNumber) : null,
      ),
      ..._outlineTiles(n.children, depth + 1),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final isBookmarked = _book.bookmarks.any((b) => b.position == '$_page');
    Widget viewer = PdfViewer.file(
      widget.repository.filePathOf(_book),
      controller: _controller,
      initialPageNumber: _initialPage,
      params: PdfViewerParams(
        backgroundColor: _invert ? const Color(0xFFD0D0D0) : _settings.theme.background,
        onViewerReady: _onViewerReady,
        onPageChanged: _onPageChanged,
      ),
    );
    if (_invert) {
      viewer = ColorFiltered(colorFilter: const ColorFilter.matrix(_invertMatrix), child: viewer);
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(_book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: isBookmarked ? 'Rimuovi segnalibro' : 'Aggiungi segnalibro',
            icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border),
            onPressed: _pageCount == 0 ? null : _toggleBookmark,
          ),
          IconButton(
            tooltip: 'Tema',
            icon: const Icon(Icons.palette_outlined),
            onPressed: () => ReaderSettingsSheet.show(
              context,
              settings: _settings,
              onChanged: _applySettings,
              showTextOptions: false,
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(icon: Icon(Icons.toc), text: 'Indice'),
                    Tab(icon: Icon(Icons.bookmark_outline), text: 'Segnalibri'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _outline.isEmpty
                          ? const Center(child: Text('Indice non disponibile'))
                          : ListView(children: _outlineTiles(_outline, 0)),
                      _book.bookmarks.isEmpty
                          ? const Center(child: Text('Nessun segnalibro'))
                          : ListView(
                              children: [
                                for (final b in _book.bookmarks)
                                  ListTile(
                                    leading: const Icon(Icons.bookmark),
                                    title: Text(b.label),
                                    onTap: () => _goTo(int.tryParse(b.position) ?? 1),
                                    trailing: IconButton(
                                      tooltip: 'Elimina',
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () async {
                                        _book.bookmarks.remove(b);
                                        await widget.repository.update(_book, notify: false);
                                        setState(() {});
                                      },
                                    ),
                                  ),
                              ],
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: viewer),
          Material(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Indice',
                    icon: const Icon(Icons.toc),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  IconButton(
                    tooltip: 'Pagina precedente',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _page > 1 ? () => _goTo(_page - 1) : null,
                  ),
                  Expanded(
                    child: _pageCount > 1
                        ? Slider(
                            value: _page.toDouble().clamp(1, _pageCount.toDouble()),
                            min: 1,
                            max: _pageCount.toDouble(),
                            divisions: _pageCount - 1,
                            label: '$_page',
                            onChanged: (v) => setState(() => _page = v.round()),
                            onChangeEnd: (v) => _goTo(v.round()),
                          )
                        : const SizedBox.shrink(),
                  ),
                  TextButton(
                    onPressed: _pageCount == 0 ? null : _askPage,
                    child: Text(_pageCount == 0 ? '–' : '$_page / $_pageCount'),
                  ),
                  IconButton(
                    tooltip: 'Pagina successiva',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _page < _pageCount ? () => _goTo(_page + 1) : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
