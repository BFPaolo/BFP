# BFP-eReader

Lettore di ebook **EPUB** e **PDF** scritto in Flutter.

## Funzionalità

- **Libreria locale**: importazione di file `.epub` / `.pdf`, ricerca per titolo/autore, ordinamento, avanzamento per libro, modifica di titolo/autore, rimozione.
- **Lettore EPUB** (epub.js via [`flutter_epub_viewer`](https://pub.dev/packages/flutter_epub_viewer)):
  - ripresa automatica dall'ultima posizione (CFI);
  - indice dei capitoli annidato, barra di avanzamento con salto a percentuale;
  - ricerca full-text nel libro;
  - evidenziazioni in 4 colori (selezione testo → barra colori o menu contestuale "Evidenzia"), copia testo;
  - segnalibri con estratto della pagina;
  - temi Chiaro / Seppia / Scuro / Nero, dimensione carattere, interlinea, font, modalità a pagine o a scorrimento;
  - tocco al centro della pagina per la lettura a schermo intero.
- **Lettore PDF** (PDFium via [`pdfrx`](https://pub.dev/packages/pdfrx)): ripresa dall'ultima pagina, indice (outline), "vai a pagina", segnalibri, modalità notte con inversione colori.

## Perché non `e_book_reader`

`e_book_reader` (0.0.13) impagina solo stringhe di testo semplice: non legge file EPUB, non gestisce
indice, immagini, CSS o posizioni CFI. `flutter_epub_viewer` 2.x si basa su epub.js (standard aperto,
ampiamente usato) e offre evidenziazioni, ricerca e CFI; per i PDF `pdfrx` usa PDFium ed è
multipiattaforma.

## Persistenza

Nessun database proprietario: nella cartella *application support* dell'app (`bfp_ereader/`) si trovano

- `books/` — copie dei file importati (`<id>.epub` / `<id>.pdf`);
- `library.json` — metadati, posizione, evidenziazioni e segnalibri di ogni libro;
- `settings.json` — preferenze di lettura.

Le scritture sono serializzate e atomiche (file temporaneo + rename).

## Struttura

```
lib/
  main.dart
  models/        book.dart (Book, Highlight, Bookmark), reader_settings.dart
  services/      library_repository.dart (import, persistenza JSON)
  screens/       library_screen.dart, epub_reader_screen.dart, epub_search_screen.dart, pdf_reader_screen.dart
  widgets/       book_cover.dart, reader_settings_sheet.dart
```

## Piattaforme

Android, iOS e macOS (i vincoli arrivano da `flutter_epub_viewer`, basato su `flutter_inappwebview`).

- **Android**: `android:usesCleartextTraffic="true"` è già impostato nel manifest (richiesto dal viewer EPUB).
- **macOS**: entitlements `network.client` e `files.user-selected.read-only` già aggiunti; target minimo 10.13+.

Il web richiederebbe una persistenza diversa (niente filesystem: IndexedDB) ed è escluso per ora.

## Avvio

```bash
flutter pub get
flutter run
flutter test
```

Richiede Flutter ≥ 3.47 (Dart ≥ 3.13).
