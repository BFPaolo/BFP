import 'package:bfp_ereader/models/book.dart';
import 'package:bfp_ereader/models/reader_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Book JSON round-trip preserva posizione, evidenziazioni e segnalibri', () {
    final book = Book(
      id: 'abc',
      title: 'Titolo',
      author: 'Autore',
      fileName: 'abc.epub',
      format: BookFormat.epub,
      addedAt: DateTime(2026, 1, 1),
      lastPosition: 'epubcfi(/6/4!/4/2/1:0)',
      progress: 0.42,
      highlights: [
        Highlight(
          cfi: 'epubcfi(/6/4!/4/2,/1:0,/1:10)',
          text: 'ciao',
          colorValue: 0xFFFFEB3B,
          createdAt: DateTime(2026),
        ),
      ],
      bookmarks: [Bookmark(position: 'epubcfi(/6/4)', label: 'Cap. 1', progress: 0.1, createdAt: DateTime(2026))],
    );

    final copy = Book.fromJson(book.toJson());

    expect(copy.title, 'Titolo');
    expect(copy.format, BookFormat.epub);
    expect(copy.lastPosition, book.lastPosition);
    expect(copy.progress, 0.42);
    expect(copy.highlights.single.text, 'ciao');
    expect(copy.bookmarks.single.label, 'Cap. 1');
  });

  test('ReaderSettings tollera valori sconosciuti', () {
    final s = ReaderSettings.fromJson({'theme': 'inesistente', 'fontSize': 20});
    expect(s.theme, ReaderThemeMode.light);
    expect(s.fontSize, 20);
    expect(ReaderSettings.fromJson(s.copyWith(scrolled: true).toJson()).scrolled, isTrue);
  });
}
