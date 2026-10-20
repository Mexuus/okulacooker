import 'dart:typed_data';

import 'package:flutter/material.dart' show Color;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/recipe.dart';
import '../data/catalog.dart';
import '../widgets/recipe_image.dart';
import 'format.dart';

PdfColor _pdf(Color c) => PdfColor.fromInt(c.toARGB32());

/// Builds a printable / shareable recipe PDF, including a generated "photo"
/// header, serving-scaled ingredients, and steps.
Future<Uint8List> buildRecipePdf(Recipe recipe, int servings) async {
  final doc = pw.Document();
  final scale = servings / recipe.baseServings;
  final colors = gradientForRecipe(recipe.id);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [
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
            recipe.title,
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
        ...recipe.ingredients.map((ri) {
          final ing = kIngredients[ri.ingredientId];
          if (ing == null) return pw.SizedBox();
          return pw.Bullet(text: formatAmount(ing, ri.qty * scale));
        }),
        pw.SizedBox(height: 16),
        pw.Text('Steps',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        ...recipe.steps.asMap().entries.map((e) {
          final text = applyStepTokens(e.value, recipe, scale);
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('${e.key + 1}.  ',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Expanded(child: pw.Text(text)),
              ],
            ),
          );
        }),
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
