import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/book.dart';
import '../models/reader_settings.dart';

/// Libreria locale: i file vengono copiati nella cartella dati dell'app e i
/// metadati salvati in un JSON leggibile (library.json), niente DB proprietari.
class LibraryRepository extends ChangeNotifier {
  LibraryRepository._(this._rootDir);

  static const supportedExtensions = ['epub', 'pdf'];

  final Directory _rootDir;
  final List<Book> _books = [];
  ReaderSettings _settings = const ReaderSettings();

  /// Serializza le scritture su disco per evitare race tra salvataggi ravvicinati.
  Future<void> _writeQueue = Future.value();

  List<Book> get books => List.unmodifiable(_books);
  ReaderSettings get settings => _settings;

  Directory get _booksDir => Directory(p.join(_rootDir.path, 'books'));
  File get _libraryFile => File(p.join(_rootDir.path, 'library.json'));
  File get _settingsFile => File(p.join(_rootDir.path, 'settings.json'));

  static Future<LibraryRepository> open() async {
    final support = await getApplicationSupportDirectory();
    final root = Directory(p.join(support.path, 'bfp_ereader'));
    final repo = LibraryRepository._(root);
    await repo._load();
    return repo;
  }

  String filePathOf(Book book) => p.join(_booksDir.path, book.fileName);

  Future<void> _load() async {
    await _booksDir.create(recursive: true);

    if (await _libraryFile.exists()) {
      try {
        final json = jsonDecode(await _libraryFile.readAsString()) as Map<String, dynamic>;
        final list = json['books'] as List<dynamic>? ?? [];
        _books
          ..clear()
          ..addAll(list.map((e) => Book.fromJson(e as Map<String, dynamic>)));
        // Scarta voci il cui file non esiste più.
        _books.removeWhere((b) => !File(filePathOf(b)).existsSync());
      } catch (e) {
        debugPrint('library.json non leggibile: $e');
      }
    }

    if (await _settingsFile.exists()) {
      try {
        _settings = ReaderSettings.fromJson(jsonDecode(await _settingsFile.readAsString()) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('settings.json non leggibile: $e');
      }
    }
  }

  /// Apre il selettore file e importa gli EPUB/PDF scelti. Ritorna i libri aggiunti.
  Future<List<Book>> pickAndImport() async {
    final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: supportedExtensions);
    final added = <Book>[];
    for (final file in picked) {
      final ext = (file.extension ?? p.extension(file.name).replaceFirst('.', '')).toLowerCase();
      if (!supportedExtensions.contains(ext)) continue;
      final bytes = await file.readAsBytes();
      added.add(await importBytes(bytes, originalName: file.name));
    }
    return added;
  }

  Future<Book> importBytes(Uint8List bytes, {required String originalName}) async {
    final ext = p.extension(originalName).replaceFirst('.', '').toLowerCase();
    final format = ext == 'pdf' ? BookFormat.pdf : BookFormat.epub;
    final id = _newId();
    final fileName = '$id.$ext';

    await File(p.join(_booksDir.path, fileName)).writeAsBytes(bytes, flush: true);

    final book = Book(
      id: id,
      title: _titleFromFileName(originalName),
      fileName: fileName,
      format: format,
      addedAt: DateTime.now(),
    );
    _books.add(book);
    await _persist();
    notifyListeners();
    return book;
  }

  Future<void> delete(Book book) async {
    _books.removeWhere((b) => b.id == book.id);
    final file = File(filePathOf(book));
    if (await file.exists()) await file.delete();
    await _persist();
    notifyListeners();
  }

  /// Da chiamare dopo aver modificato un [Book] (progresso, titolo, evidenziazioni...).
  Future<void> update(Book book, {bool notify = true}) async {
    await _persist();
    if (notify) notifyListeners();
  }

  Future<void> updateSettings(ReaderSettings settings) async {
    _settings = settings;
    notifyListeners();
    await _enqueueWrite(_settingsFile, jsonEncode(settings.toJson()));
  }

  Future<void> _persist() => _enqueueWrite(
    _libraryFile,
    const JsonEncoder.withIndent('  ').convert({'version': 1, 'books': _books.map((b) => b.toJson()).toList()}),
  );

  Future<void> _enqueueWrite(File target, String content) {
    _writeQueue = _writeQueue
        .then((_) async {
          // Scrittura atomica: file temporaneo + rename.
          final tmp = File('${target.path}.tmp');
          await tmp.writeAsString(content, flush: true);
          await tmp.rename(target.path);
        })
        .catchError((Object e) => debugPrint('Salvataggio fallito: $e'));
    return _writeQueue;
  }

  static String _titleFromFileName(String name) {
    final base = p.basenameWithoutExtension(name).replaceAll(RegExp(r'[_\-]+'), ' ').trim();
    return base.isEmpty ? 'Senza titolo' : base;
  }

  static String _newId() {
    final rnd = Random.secure();
    final suffix = List.generate(6, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    return '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}$suffix';
  }
}
