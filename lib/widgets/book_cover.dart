import 'package:flutter/material.dart';

import '../models/book.dart';

/// Copertina generata (colore derivato dal titolo), nessuna estrazione immagini.
class BookCover extends StatelessWidget {
  const BookCover({super.key, required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final hue = (book.title.hashCode % 360).abs().toDouble();
    final base = HSLColor.fromAHSL(1, hue, 0.45, 0.42).toColor();
    final dark = HSLColor.fromAHSL(1, hue, 0.5, 0.25).toColor();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [base, dark]),
        boxShadow: const [BoxShadow(blurRadius: 4, offset: Offset(0, 2), color: Colors.black26)],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            book.title,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15, height: 1.2),
          ),
          const Spacer(),
          if (book.author != null)
            Text(
              book.author!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
            child: Text(
              book.format.name.toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
