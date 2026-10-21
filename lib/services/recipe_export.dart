import 'dart:typed_data';

import 'package:flutter/material.dart' show Color;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/recipe.dart';
import '../widgets/recipe_image.dart';
import 'format.dart';

PdfColor _pdf(Color c) => PdfColor.fromInt(c.toARGB32());

const _fractions = {
  '⅛': '1/8', '¼': '1/4', '⅓': '1/3', '⅜': '3/8', '½': '1/2',
  '⅝': '5/8', '⅔': '2/3', '¾': '3/4', '⅞': '7/8',
};

/// The PDF's built-in font lacks some glyphs; write fractions and dashes out.
String _pdfText(String s) => s
    .replaceAllMapped(RegExp('(\\d?)([${_fractions.keys.join()}])'),
        (m) => '${m[1]!.isEmpty ? '' : '${m[1]} '}${_fractions[m[2]]}')
    .replaceAll('–', '-')
    .replaceAll('—', ' - ')
    .replaceAll('×', 'x');

/// Builds a printable / shareable recipe PDF: a header with the dish photo
/// (or a coloured banner), serving-scaled ingredients, and steps.
Future<Uint8List> buildRecipePdf(Recipe recipe, int servings) async {
  final doc = pw.Document();
  final scale = servings / recipe.baseServings;
  final colors = gradientForRecipe(recipe);
  pw.ImageProvider? photo;
  final p = recipe.photo;
  if (p != null) {
    try {
      final bytes = await rootBundle.load(p.asset);
      photo = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      photo = null;
    }
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [
        if (photo != null) ...[
          pw.ClipRRect(
            horizontalRadius: 16,
            verticalRadius: 16,
            child: pw.Image(photo, height: 220, width: double.infinity, fit: pw.BoxFit.cover),
          ),
          pw.SizedBox(height: 4),
          pw.Text(_pdfText(p!.attribution),
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          pw.SizedBox(height: 10),
          pw.Text(_pdfText(recipe.title),
              style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold)),
        ] else
        // Photo-style gradient banner.
        pw.Container(
          height: 150,
          width: double.infinity,
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [_pdf(colors[0]), _pdf(colors[1])],
              begin: pw.Alignment.topLeft,
              end: pw.Alignment.bottomRight,
            ),
            borderRadius: pw.BorderRadius.circular(16),
          ),
          alignment: pw.Alignment.center,
          child: pw.Text(
            _pdfText(recipe.title),
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 28,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          'Serves $servings  •  ${recipe.totalMinutes} min'
          '  •  ${recipe.tags.join(', ')}',
          style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 12),
        ),
        pw.SizedBox(height: 16),
        pw.Text('Ingredients',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        for (final ri in recipe.ingredients)
          pw.Bullet(text: _pdfText(formatRecipeAmount(ri, scale))),
        pw.SizedBox(height: 16),
        pw.Text('Directions',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        for (final (i, phase) in recipe.phases.indexed) ...[
          pw.SizedBox(height: 10),
          pw.Text(
            '${i + 1}. ${phase.name}${phase.minutes > 0 ? '  (${phase.minutes} min)' : ''}',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          for (final a in phase.actions)
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 12, bottom: 5),
              child: pw.RichText(
                text: pw.TextSpan(children: [
                  pw.TextSpan(
                      text: '${a.verb} ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.TextSpan(text: _pdfText(renderActionBody(a, scale))),
                ]),
              ),
            ),
        ],
        pw.SizedBox(height: 24),
        pw.Text(
          'Made with TapCook. Prices are estimates; always review ingredients, '
          'measurements, cooking instructions, and allergy information before cooking.',
          style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 9),
        ),
      ],
    ),
  );

  return doc.save();
}

Future<void> printRecipe(Recipe recipe, int servings) async {
  await Printing.layoutPdf(
    onLayout: (_) => buildRecipePdf(recipe, servings),
    name: recipe.title,
  );
}

Future<void> shareRecipe(Recipe recipe, int servings) async {
  final bytes = await buildRecipePdf(recipe, servings);
  await Printing.sharePdf(
    bytes: bytes,
    filename: '${recipe.id}.pdf',
  );
}
