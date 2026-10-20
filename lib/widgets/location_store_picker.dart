import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/regions.dart';
import '../data/stores.dart';
import '../services/location_service.dart';
import '../services/store_locator.dart';
import '../state/app_state.dart';

/// ZIP entry with "Use my location", offline ZIP validation, nearby-store
/// discovery, and a full store list sorted by what operates in the user's state.
class LocationStorePicker extends StatefulWidget {
  final String zip;
  final String storeId;
  final ValueChanged<String> onZipChanged;
  final ValueChanged<String> onStoreChanged;
  final bool showZipError;

  /// Pre-selects the nearest store until the user picks one themselves
  /// (used during onboarding; Settings keeps the saved choice).
  final bool autoSelectNearest;

  const LocationStorePicker({
    super.key,
    required this.zip,
    required this.storeId,
    required this.onZipChanged,
    required this.onStoreChanged,
    this.showZipError = false,
    this.autoSelectNearest = false,
  });

  @override
  State<LocationStorePicker> createState() => _LocationStorePickerState();
}

class _LocationStorePickerState extends State<LocationStorePicker> {
  late final TextEditingController _zip =
      TextEditingController(text: widget.zip);

  PlaceInfo? _place;
  bool _unknownZip = false;
  bool _locating = false;
  String? _locError;

  List<NearbyStore>? _nearby;
  bool _searching = false;
  String? _storeError;
  int _req = 0;
  bool _userPickedStore = false;

  void _pickStore(String id) {
    _userPickedStore = true;
    widget.onStoreChanged(id);
  }

  @override
  void initState() {
    super.initState();
    if (isValidZip(widget.zip)) _resolve(widget.zip);
  }

  @override
  void dispose() {
    _zip.dispose();
    super.dispose();
  }

  AppState get _app => context.read<AppState>();

  void _onZipChanged(String v) {
    widget.onZipChanged(v);
    setState(() {
      _locError = null;
      if (!isValidZip(v)) {
        _place = null;
        _unknownZip = false;
        _nearby = null;
        _storeError = null;
      }
    });
    if (isValidZip(v)) _resolve(v);
  }

  Future<void> _resolve(String zip) async {
    final req = ++_req;
    final place = await _app.location.resolveZip(zip);
    if (!mounted || req != _req) return;
    setState(() {
      _place = place;
      _unknownZip = place == null;
      _nearby = null;
      _storeError = null;
    });
    if (place != null) _search(place, req);
  }

  Future<void> _search(PlaceInfo place, int req) async {
    setState(() {
      _searching = true;
      _storeError = null;
    });
    try {
      final all = await _app.nearbyStores(place);
      if (!mounted || req != _req) return;
      final perChain = StoreLocator.closestPerChain(all);
      setState(() => _nearby = perChain);
      if (widget.autoSelectNearest && !_userPickedStore && perChain.isNotEmpty) {
        widget.onStoreChanged(perChain.first.store.id);
      }
    } on StoreLookupException catch (e) {
      if (!mounted || req != _req) return;
      setState(() => _storeError = e.message);
    } finally {
      if (mounted && req == _req) setState(() => _searching = false);
    }
  }

  Future<void> _useMyLocation() async {
    setState(() {
      _locating = true;
      _locError = null;
    });
    try {
      final place = await _app.detectLocation();
      if (!mounted) return;
      final req = ++_req;
      _zip.text = place.zip;
      widget.onZipChanged(place.zip);
      setState(() {
        _place = place;
        _unknownZip = false;
        _nearby = null;
      });
      _search(place, req);
    } on LocationException catch (e) {
      if (mounted) setState(() => _locError = e.message);
    } catch (e) {
      if (mounted) {
        setState(() => _locError = 'Couldn’t determine your location.');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final zipOk = isValidZip(_zip.text);
    final place = _place;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _zip,
                keyboardType: TextInputType.number,
                maxLength: 5,
                onChanged: _onZipChanged,
                decoration: InputDecoration(
                  labelText: 'ZIP code',
                  hintText: '90210',
                  border: const OutlineInputBorder(),
                  counterText: '',
                  errorText: (widget.showZipError && !zipOk)
                      ? 'Enter a valid 5-digit US ZIP'
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 56,
              child: FilledButton.tonalIcon(
                onPressed: _locating ? null : _useMyLocation,
                icon: _locating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location),
                label: const Text('Locate'),
              ),
            ),
          ],
        ),
        if (_locError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_locError!,
                style: TextStyle(color: theme.colorScheme.error)),
          ),
        if (place != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Icon(Icons.place_outlined,
                    size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${place.stateName} · ${place.region.name} pricing',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        if (_unknownZip && zipOk)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'We don’t recognise that ZIP — using regional pricing for its area.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.amber.shade800),
            ),
          ),
        const SizedBox(height: 16),
        if (place != null) _buildNearby(theme, place),
        DropdownButtonFormField<String>(
          key: ValueKey('store-${widget.storeId}-${place?.state}'),
          initialValue: widget.storeId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Grocery store',
            border: OutlineInputBorder(),
          ),
          items: storesForState(place?.state)
              .map((s) => DropdownMenuItem(
                    value: s.id,
                    child: Text(
                      place?.state != null && !s.operatesIn(place!.state)
                          ? '${s.name}  (not common in ${place.state})'
                          : s.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) _pickStore(v);
          },
        ),
        const SizedBox(height: 6),
        Text(
          'US grocery stores only. Store locations: All The Places (CC0) and '
          '${StoreLocator.attribution}. ZIP data: U.S. Census Bureau.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildNearby(ThemeData theme, PlaceInfo place) {
    final nearby = _nearby;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Stores near ${place.zip}',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              if (_searching)
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else
                IconButton(
                  tooltip: 'Search again',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () => _search(place, _req),
                ),
            ],
          ),
          if (_storeError != null) ...[
            Text(_storeError!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.amber.shade800)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: storesForState(place.state)
                  .where((s) => !s.isNational && s.operatesIn(place.state))
                  .take(8)
                  .map((s) => ChoiceChip(
                        label: Text(s.name),
                        selected: s.id == widget.storeId,
                        onSelected: (_) => _pickStore(s.id),
                      ))
                  .toList(),
            ),
          ] else if (nearby != null && nearby.isEmpty)
            Text('No supported chains found nearby. Pick from the list below.',
                style: theme.textTheme.bodySmall)
          else if (nearby != null)
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final n in nearby.take(6))
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.storefront_outlined),
                      title: Text(n.displayName),
                      subtitle: Text([
                        '${n.distanceMi.toStringAsFixed(1)} mi',
                        if (n.isOtherBanner) 'priced as ${n.store.name}',
                        if (n.address != null) n.address!,
                      ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      trailing: n.store.id == widget.storeId
                          ? Icon(Icons.check_circle,
                              color: theme.colorScheme.primary)
                          : null,
                      onTap: () => _pickStore(n.store.id),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
