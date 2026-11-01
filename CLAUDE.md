# BFP-eReader — istruzioni di progetto

Lettore EPUB e PDF in **Flutter** (pacchetto `bfp_ereader`). Rispondere in
italiano; commenti e testi UI in italiano, identificatori in inglese.
Leggere il README prima di modifiche estese.

## Stack

- Flutter stable, Dart `^3.13` con null safety; lint `flutter_lints`
  (`analysis_options.yaml`).
- EPUB: `flutter_epub_viewer` 2.x (epub.js su `flutter_inappwebview`),
  posizioni in CFI.
- PDF: `pdfrx` (PDFium).
- File: `file_picker`, `path_provider`, `path`.
- Stato: `LibraryRepository` (`ChangeNotifier`) + `setState` nelle schermate.
  Nessuna libreria di stato: non introdurre Riverpod, Bloc o Provider senza
  una decisione esplicita.
- Piattaforme: Android, iOS, macOS. Web escluso (serve il filesystem).

Le API dei pacchetti cambiano tra major: prima di usarne una, verificare la
versione risolta in `pubspec.lock`. Nuove dipendenze solo su richiesta,
preferendo componenti aperti.

## Struttura

```
lib/
  main.dart
  models/    book.dart (Book, Highlight, Bookmark), reader_settings.dart
  services/  library_repository.dart (import, persistenza JSON)
  screens/   library, epub_reader, epub_search, pdf_reader
  widgets/   book_cover, reader_settings_sheet
test/        widget_test.dart (round-trip JSON dei modelli)
```

## Dati: formato da conservare

Nella cartella *application support* dell'app, sottocartella `bfp_ereader/`:

- `books/<id>.epub|pdf` — copie dei file importati;
- `library.json` — metadati, posizione, evidenziazioni, segnalibri;
- `settings.json` — preferenze di lettura.

Sono contratti con le installazioni esistenti: campi nuovi solo opzionali con
default, nessun campo rinominato o rimosso senza migrazione in `fromJson`.
Le scritture passano dalla coda `_writeQueue` e sono atomiche (file temporaneo
+ rename): non scrivere i file JSON per altre vie.

## Vincoli

- Android: `usesCleartextTraffic="true"` nel manifest è richiesto dal viewer
  EPUB, non rimuoverlo.
- macOS: entitlements `network.client` e `files.user-selected.read-only`.
- Non cambiare `applicationId` (`it.bfp.bfp_ereader`) né il bundle id senza
  decisione esplicita.

## Metodo

- Modifiche mirate: non riformattare né riscrivere codice non coinvolto.
- Per file nuovi o modifiche estese fornire il file completo.
- Prima di dichiarare finito: `flutter analyze` senza issue e `flutter test`
  verde, mostrando l'output.
- Modelli toccati → aggiornare `toJson`/`fromJson` e il test di round-trip.

## Comandi

```bash
flutter pub get
flutter analyze
dart format lib test
flutter test
flutter run
```
