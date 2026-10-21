import 'package:flutter/material.dart';

import '../data/recipe_db.dart';
import '../models/recipe.dart';

/// Attribution for bundled photos, icons and data, as their licenses require.
class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photos = <String, (RecipePhoto, List<String>)>{};
    for (final r in kRecipes) {
      final p = r.photo;
      if (p == null) continue;
      photos.putIfAbsent(p.file, () => (p, <String>[])).$2.add(r.title);
    }
    final entries = photos.values.toList()
      ..sort((a, b) => a.$2.first.compareTo(b.$2.first));

    Widget source(String title, String body) => ListTile(
          title: Text(title),
          subtitle: Text(body),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Credits')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Data', style: theme.textTheme.titleMedium),
          ),
          source('Prices', 'U.S. Bureau of Labor Statistics average prices (public domain) and '
              'USDA ERS Food-at-Home Monthly Area Prices.'),
          source('Store locations', 'All The Places (CC0) and © OpenStreetMap contributors (ODbL).'),
          source('ZIP codes', 'U.S. Census Bureau ZIP Code Tabulation Areas (public domain).'),
          source('Food icons', 'Microsoft Fluent Emoji, 3D style — MIT License, '
              'github.com/microsoft/fluentui-emoji.'),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text('Recipe photos (${entries.length})', style: theme.textTheme.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'From Wikimedia Commons under the licenses shown, cropped and resized. '
              'Photos show the style of dish and may differ from the recipe.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          for (final (p, titles) in entries)
            ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(p.asset, width: 56, height: 42, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(width: 56, height: 42)),
              ),
              title: Text(titles.length == 1 ? titles.first : '${titles.first} +${titles.length - 1} more',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: SelectableText(
                  '${p.credit.isEmpty ? 'Unknown author' : p.credit} · ${p.license}\n${p.source}',
                  style: theme.textTheme.bodySmall),
              isThreeLine: true,
            ),
          if (entries.isEmpty)
            const ListTile(title: Text('No photos bundled in this build.')),
        ],
      ),
    );
  }
}
