enum BookFormat { epub, pdf }

/// Evidenziazione salvata su un EPUB (identificata dal suo CFI range).
class Highlight {
  Highlight({required this.cfi, required this.text, required this.colorValue, required this.createdAt, this.note});

  final String cfi;
  final String text;
  final int colorValue;
  final DateTime createdAt;
  String? note;

  factory Highlight.fromJson(Map<String, dynamic> json) => Highlight(
    cfi: json['cfi'] as String,
    text: json['text'] as String? ?? '',
    colorValue: json['color'] as int? ?? 0xFFFFEB3B,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    note: json['note'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'cfi': cfi,
    'text': text,
    'color': colorValue,
    'createdAt': createdAt.toIso8601String(),
    if (note != null) 'note': note,
  };
}

/// Segnalibro: per EPUB [position] è un CFI, per PDF il numero di pagina.
class Bookmark {
  Bookmark({required this.position, required this.label, required this.progress, required this.createdAt});

  final String position;
  final String label;
  final double progress;
  final DateTime createdAt;

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
    position: json['position'] as String,
    label: json['label'] as String? ?? '',
    progress: (json['progress'] as num?)?.toDouble() ?? 0,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'position': position,
    'label': label,
    'progress': progress,
    'createdAt': createdAt.toIso8601String(),
  };
}

class Book {
  Book({
    required this.id,
    required this.title,
    required this.fileName,
    required this.format,
    required this.addedAt,
    this.author,
    this.lastOpenedAt,
    this.lastPosition,
    this.progress = 0,
    List<Highlight>? highlights,
    List<Bookmark>? bookmarks,
  }) : highlights = highlights ?? [],
       bookmarks = bookmarks ?? [];

  final String id;
  String title;
  String? author;

  /// Nome del file dentro la cartella della libreria (non path assoluto:
  /// su iOS il container dell'app cambia path tra un aggiornamento e l'altro).
  final String fileName;
  final BookFormat format;
  final DateTime addedAt;
  DateTime? lastOpenedAt;

  /// Ultima posizione di lettura: CFI per EPUB, numero di pagina per PDF.
  String? lastPosition;

  /// Avanzamento 0.0 - 1.0.
  double progress;

  final List<Highlight> highlights;
  final List<Bookmark> bookmarks;

  factory Book.fromJson(Map<String, dynamic> json) => Book(
    id: json['id'] as String,
    title: json['title'] as String,
    author: json['author'] as String?,
    fileName: json['fileName'] as String,
    format: BookFormat.values.byName(json['format'] as String),
    addedAt: DateTime.parse(json['addedAt'] as String),
    lastOpenedAt: DateTime.tryParse(json['lastOpenedAt'] as String? ?? ''),
    lastPosition: json['lastPosition'] as String?,
    progress: (json['progress'] as num?)?.toDouble() ?? 0,
    highlights: (json['highlights'] as List<dynamic>? ?? [])
        .map((e) => Highlight.fromJson(e as Map<String, dynamic>))
        .toList(),
    bookmarks: (json['bookmarks'] as List<dynamic>? ?? [])
        .map((e) => Bookmark.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (author != null) 'author': author,
    'fileName': fileName,
    'format': format.name,
    'addedAt': addedAt.toIso8601String(),
    if (lastOpenedAt != null) 'lastOpenedAt': lastOpenedAt!.toIso8601String(),
    if (lastPosition != null) 'lastPosition': lastPosition,
    'progress': progress,
    'highlights': highlights.map((e) => e.toJson()).toList(),
    'bookmarks': bookmarks.map((e) => e.toJson()).toList(),
  };
}
