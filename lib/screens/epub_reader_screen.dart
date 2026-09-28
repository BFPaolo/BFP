import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';

import '../models/book.dart';
import '../models/reader_settings.dart';
import '../services/library_repository.dart';
import '../widgets/reader_settings_sheet.dart';
import 'epub_search_screen.dart';

const _highlightColors = <Color>[
  Color(0xFFFFEB3B), // giallo
  Color(0xFF81C784), // verde
  Color(0xFF64B5F6), // azzurro
  Color(0xFFF48FB1), // rosa
];

class EpubReaderScreen extends StatefulWidget {
  const EpubReaderScreen({super.key, required this.repository, required this.book});

  final LibraryRepository repository;
  final Book book;

  @override
  State<EpubReaderScreen> createState() => _EpubReaderScreenState();
}

class _EpubReaderScreenState extends State<EpubReaderScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Il libro viene letto in memoria e passato come dati (niente `EpubSource.fromFile`,
  /// che dipende da un import condizionale del pacchetto).
  EpubSource? _source;
  String? _loadError;
  EpubController _controller = EpubController();
  late ReaderSettings _settings = widget.repository.settings;

  /// Cambia quando serve ricreare il viewer (tema, font, flow): il libro viene
  /// ricaricato dalla posizione corrente.
  int _viewerGeneration = 0;

  bool _loaded = false;
  bool _showChrome = true;
  List<EpubChapter> _chapters = [];
  EpubTextSelection? _selection;
  double _progress = 0;
  double? _dragProgress;

  Book get _book => widget.book;

  @override
  void initState() {
    super.initState();
    _progress = _book.progress;
    File(widget.repository.filePathOf(_book))
        .readAsBytes()
        .then((bytes) {
          if (mounted) setState(() => _source = EpubSource.fromData(bytes));
        })
        .catchError((Object e) {
          if (mounted) setState(() => _loadError = 'Impossibile aprire il file: $e');
        });
  }

  // ---------------------------------------------------------------- tema/CSS

  static String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  EpubTheme _buildTheme() {
    final t = _settings.theme;
    final bodyCss = <String, String>{
      'background': '${_hex(t.background)} !important',
      'color': '${_hex(t.foreground)} !important',
      'line-height': '${_settings.lineHeight} !important',
    };
    final pCss = <String, String>{'line-height': '${_settings.lineHeight} !important', 'color': 'inherit !important'};
    final font = _settings.fontFamily.css;
    if (font != null) {
      bodyCss['font-family'] = '$font !important';
      pCss['font-family'] = '$font !important';
    }
    return EpubTheme.custom(
      backgroundDecoration: BoxDecoration(color: t.background),
      foregroundColor: t.foreground,
      customCss: {
        'body': bodyCss,
        'p': pCss,
        'span, div, li, h1, h2, h3, h4, h5, h6': {'color': 'inherit !important'},
        'a, a:link, a:visited': {
          'color': '${_hex(Theme.of(context).colorScheme.primary)} !important',
          '-webkit-text-fill-color': 'inherit !important',
        },
      },
    );
  }

  // ---------------------------------------------------------------- callback viewer

  Future<void> _onEpubLoaded() async {
    setState(() => _loaded = true);
    for (final h in _book.highlights) {
      _controller.addHighlight(cfi: h.cfi, color: Color(h.colorValue), opacity: 0.35);
    }
    if (_book.author == null) {
      try {
        final meta = await _controller.getMetadata();
        final title = meta.title?.trim();
        final author = meta.author?.trim();
        if (title != null && title.isNotEmpty) _book.title = title;
        if (author != null && author.isNotEmpty) _book.author = author;
        await widget.repository.update(_book);
        if (mounted) setState(() {});
      } catch (_) {
        // Metadati opzionali: si tiene il nome file.
      }
    }
  }

  void _onRelocated(EpubLocation location) {
    _book
      ..lastPosition = location.startCfi
      ..progress = location.progress.clamp(0.0, 1.0);
    unawaited(widget.repository.update(_book, notify: false));
    if (mounted) setState(() => _progress = _book.progress);
  }

  void _onTouchUp(double x, double y) {
    // Tocco al centro: mostra/nasconde barre.
    if (_selection == null && x > 0.3 && x < 0.7 && y > 0.2 && y < 0.8) {
      setState(() => _showChrome = !_showChrome);
    }
  }

  // ---------------------------------------------------------------- impostazioni

  void _applySettings(ReaderSettings s) {
    final old = _settings;
    setState(() => _settings = s);
    unawaited(widget.repository.updateSettings(s));

    final needsReload =
        old.theme != s.theme ||
        old.fontFamily != s.fontFamily ||
        old.lineHeight != s.lineHeight ||
        old.scrolled != s.scrolled;
    if (needsReload) {
      setState(() {
        _loaded = false;
        _controller = EpubController();
        _viewerGeneration++;
      });
    } else if (old.fontSize != s.fontSize && _loaded) {
      _controller.setFontSize(fontSize: s.fontSize.toDouble());
    }
  }

  // ---------------------------------------------------------------- evidenziazioni

  Future<void> _highlightSelection([Color? color]) async {
    final sel = _selection;
    if (sel == null || sel.selectionCfi.isEmpty) return;
    final c = color ?? _highlightColors.first;
    final h = Highlight(
      cfi: sel.selectionCfi,
      text: sel.selectedText.trim(),
      colorValue: c.toARGB32(),
      createdAt: DateTime.now(),
    );
    _book.highlights.add(h);
    _controller.addHighlight(cfi: h.cfi, color: c, opacity: 0.35);
    _controller.clearSelection();
    setState(() => _selection = null);
    await widget.repository.update(_book, notify: false);
  }

  Future<void> _copySelection() async {
    final sel = _selection;
    if (sel == null) return;
    await Clipboard.setData(ClipboardData(text: sel.selectedText));
    _controller.clearSelection();
    setState(() => _selection = null);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Testo copiato')));
    }
  }

  Future<void> _removeHighlight(Highlight h) async {
    _book.highlights.remove(h);
    if (_loaded) _controller.removeHighlight(cfi: h.cfi);
    await widget.repository.update(_book, notify: false);
    if (mounted) setState(() {});
  }

  Future<void> _onAnnotationClicked(String cfi, Map<String, dynamic>? _) async {
    final h = _book.highlights.where((e) => e.cfi == cfi).firstOrNull;
    if (h == null) return;
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Evidenziazione'),
        content: SingleChildScrollView(child: Text('"${h.text}"')),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: h.text));
              Navigator.pop(context, false);
            },
            child: const Text('Copia'),
          ),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Rimuovi')),
          FilledButton(onPressed: () => Navigator.pop(context, false), child: const Text('Chiudi')),
        ],
      ),
    );
    if (remove == true) await _removeHighlight(h);
  }

  // ---------------------------------------------------------------- segnalibri

  Future<void> _toggleBookmark() async {
    if (!_loaded) return;
    final existing = _currentBookmark();
    if (existing != null) {
      _book.bookmarks.remove(existing);
    } else {
      final cfi = _book.lastPosition;
      if (cfi == null) return;
      var label = '';
      try {
        final page = await _controller.extractCurrentPageText();
        label = (page.text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
        if (label.length > 90) label = '${label.substring(0, 90)}…';
      } catch (_) {}
      _book.bookmarks.add(
        Bookmark(
          position: cfi,
          label: label.isEmpty ? 'Posizione ${(_progress * 100).round()}%' : label,
          progress: _progress,
          createdAt: DateTime.now(),
        ),
      );
      _book.bookmarks.sort((a, b) => a.progress.compareTo(b.progress));
    }
    await widget.repository.update(_book, notify: false);
    if (mounted) setState(() {});
  }

  Bookmark? _currentBookmark() => _book.bookmarks.where((b) => b.position == _book.lastPosition).firstOrNull;

  // ---------------------------------------------------------------- navigazione

  void _goTo(String cfiOrHref) {
    if (!_loaded) return;
    _controller.display(cfi: cfiOrHref);
    _scaffoldKey.currentState?.closeDrawer();
  }

  Future<void> _openSearch() async {
    if (!_loaded) return;
    final cfi = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => EpubSearchScreen(controller: _controller)));
    if (cfi != null) _goTo(cfi);
  }

  // ---------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final t = _settings.theme;
    final isBookmarked = _currentBookmark() != null;
    final shownProgress = _dragProgress ?? _progress;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: t.background,
      appBar: _showChrome
          ? AppBar(
              title: Text(_book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              actions: [
                IconButton(tooltip: 'Cerca', icon: const Icon(Icons.search), onPressed: _openSearch),
                IconButton(
                  tooltip: isBookmarked ? 'Rimuovi segnalibro' : 'Aggiungi segnalibro',
                  icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border),
                  onPressed: _toggleBookmark,
                ),
                IconButton(
                  tooltip: 'Impostazioni lettura',
                  icon: const Icon(Icons.text_format),
                  onPressed: () => ReaderSettingsSheet.show(context, settings: _settings, onChanged: _applySettings),
                ),
              ],
            )
          : null,
      drawer: _NavigationDrawer(
        chapters: _chapters,
        bookmarks: _book.bookmarks,
        highlights: _book.highlights,
        onNavigate: _goTo,
        onDeleteBookmark: (b) async {
          _book.bookmarks.remove(b);
          await widget.repository.update(_book, notify: false);
          setState(() {});
        },
        onDeleteHighlight: _removeHighlight,
      ),
      body: SafeArea(
        top: !_showChrome,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  if (_source != null)
                    EpubViewer(
                      key: ValueKey(_viewerGeneration),
                      epubController: _controller,
                      epubSource: _source!,
                      initialCfi: _book.lastPosition,
                      displaySettings: EpubDisplaySettings(
                        fontSize: _settings.fontSize,
                        flow: _settings.scrolled ? EpubFlow.scrolled : EpubFlow.paginated,
                        spread: EpubSpread.auto,
                        snap: true,
                        theme: _buildTheme(),
                      ),
                      selectionContextMenu: EpubContextMenu(
                        items: [EpubContextMenuItem(id: 1, title: 'Evidenzia', action: () => _highlightSelection())],
                      ),
                      onEpubLoaded: _onEpubLoaded,
                      onChaptersLoaded: (c) => setState(() => _chapters = c),
                      onRelocated: _onRelocated,
                      onTextSelected: (s) => setState(() => _selection = s),
                      onDeselection: () => setState(() => _selection = null),
                      onAnnotationClicked: _onAnnotationClicked,
                      onTouchUp: _onTouchUp,
                    ),
                  if (_loadError != null)
                    Center(
                      child: Padding(padding: const EdgeInsets.all(24), child: Text(_loadError!)),
                    )
                  else if (!_loaded)
                    const Center(child: CircularProgressIndicator()),
                  if (_selection != null)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: _SelectionBar(onHighlight: _highlightSelection, onCopy: _copySelection),
                    ),
                ],
              ),
            ),
            if (_showChrome)
              Material(
                color: Theme.of(context).colorScheme.surfaceContainer,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
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
                          onPressed: _loaded ? () => _controller.prev() : null,
                        ),
                        Expanded(
                          child: Slider(
                            value: shownProgress.clamp(0.0, 1.0),
                            onChanged: _loaded ? (v) => setState(() => _dragProgress = v) : null,
                            onChangeEnd: (v) {
                              _controller.toProgressPercentage(v);
                              setState(() => _dragProgress = null);
                            },
                          ),
                        ),
                        SizedBox(
                          width: 44,
                          child: Text('${(shownProgress * 100).round()}%', textAlign: TextAlign.center),
                        ),
                        IconButton(
                          tooltip: 'Pagina successiva',
                          icon: const Icon(Icons.chevron_right),
                          onPressed: _loaded ? () => _controller.next() : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.onHighlight, required this.onCopy});

  final void Function([Color? color]) onHighlight;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(28),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final c in _highlightColors)
              IconButton(
                tooltip: 'Evidenzia',
                onPressed: () => onHighlight(c),
                icon: CircleAvatar(radius: 12, backgroundColor: c),
              ),
            const VerticalDivider(width: 16),
            IconButton(tooltip: 'Copia', icon: const Icon(Icons.copy), onPressed: onCopy),
          ],
        ),
      ),
    );
  }
}

/// Drawer con tre schede: indice, segnalibri, evidenziazioni.
class _NavigationDrawer extends StatelessWidget {
  const _NavigationDrawer({
    required this.chapters,
    required this.bookmarks,
    required this.highlights,
    required this.onNavigate,
    required this.onDeleteBookmark,
    required this.onDeleteHighlight,
  });

  final List<EpubChapter> chapters;
  final List<Bookmark> bookmarks;
  final List<Highlight> highlights;
  final ValueChanged<String> onNavigate;
  final ValueChanged<Bookmark> onDeleteBookmark;
  final ValueChanged<Highlight> onDeleteHighlight;

  List<Widget> _chapterTiles(List<EpubChapter> items, int depth) => [
    for (final c in items) ...[
      ListTile(
        dense: depth > 0,
        contentPadding: EdgeInsets.only(left: 16.0 + depth * 16, right: 16),
        title: Text(c.title.trim(), maxLines: 2, overflow: TextOverflow.ellipsis),
        onTap: () => onNavigate(c.href),
      ),
      ..._chapterTiles(c.subitems, depth + 1),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.toc), text: 'Indice'),
                  Tab(icon: Icon(Icons.bookmark_outline), text: 'Segnalibri'),
                  Tab(icon: Icon(Icons.border_color_outlined), text: 'Note'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    chapters.isEmpty
                        ? const Center(child: Text('Indice non disponibile'))
                        : ListView(children: _chapterTiles(chapters, 0)),
                    bookmarks.isEmpty
                        ? const Center(child: Text('Nessun segnalibro'))
                        : ListView(
                            children: [
                              for (final b in bookmarks)
                                ListTile(
                                  leading: Text('${(b.progress * 100).round()}%'),
                                  title: Text(b.label, maxLines: 2, overflow: TextOverflow.ellipsis),
                                  onTap: () => onNavigate(b.position),
                                  trailing: IconButton(
                                    tooltip: 'Elimina',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => onDeleteBookmark(b),
                                  ),
                                ),
                            ],
                          ),
                    highlights.isEmpty
                        ? const Center(child: Text('Nessuna evidenziazione'))
                        : ListView(
                            children: [
                              for (final h in highlights)
                                ListTile(
                                  leading: CircleAvatar(radius: 8, backgroundColor: Color(h.colorValue)),
                                  title: Text(h.text, maxLines: 3, overflow: TextOverflow.ellipsis),
                                  onTap: () => onNavigate(h.cfi),
                                  trailing: IconButton(
                                    tooltip: 'Elimina',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => onDeleteHighlight(h),
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
    );
  }
}
