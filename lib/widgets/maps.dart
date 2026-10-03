import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/location.dart';

TileLayer _tiles() => TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  userAgentPackageName: 'com.villagefood.village_food',
);

Marker _marker(LatLng p, IconData icon, Color color) => Marker(
  point: p,
  width: 44,
  height: 44,
  alignment: Alignment.topCenter,
  child: Icon(icon, color: color, size: 44),
);

const _attribution = RichAttributionWidget(attributions: [TextSourceAttribution('© OpenStreetMap')]);

/// Shows the delivery point and, when known, where the rider is now.
class OrderMap extends StatelessWidget {
  const OrderMap({super.key, this.dropoff, this.rider, this.height = 260});

  final LatLng? dropoff;
  final LatLng? rider;
  final double height;

  @override
  Widget build(BuildContext context) {
    final points = [?dropoff, ?rider];
    if (points.isEmpty) return const SizedBox.shrink();
    final fit = points.length == 2
        ? CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(48), maxZoom: 17)
        : null;
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          // Key on the points so the camera re-fits when the rider moves.
          key: ValueKey('${rider?.latitude},${rider?.longitude}'),
          options: MapOptions(initialCenter: points.first, initialZoom: 16, initialCameraFit: fit),
          children: [
            _tiles(),
            MarkerLayer(
              markers: [
                if (dropoff != null) _marker(dropoff!, Icons.home, Colors.red),
                if (rider != null) _marker(rider!, Icons.delivery_dining, Colors.blue),
              ],
            ),
            _attribution,
          ],
        ),
      ),
    );
  }
}

/// Full-screen picker: tap or drag the map to place the home pin.
class PinPickerScreen extends StatefulWidget {
  const PinPickerScreen({super.key, this.initial});
  final LatLng? initial;

  @override
  State<PinPickerScreen> createState() => _PinPickerScreenState();
}

class _PinPickerScreenState extends State<PinPickerScreen> {
  final _map = MapController();
  LatLng? _pin;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _pin = widget.initial;
    if (_pin == null) _locate();
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    final here = await currentLocation();
    if (!mounted) return;
    setState(() => _locating = false);
    if (here == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('หาตำแหน่งไม่ได้ กรุณาแตะบนแผนที่เพื่อปักหมุดเอง')));
      return;
    }
    setState(() => _pin = here);
    _map.move(here, 17);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ปักหมุดบ้าน')),
    body: Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: _pin ?? fallbackCenter,
            initialZoom: _pin == null ? 12 : 17,
            onTap: (_, p) => setState(() => _pin = p),
          ),
          children: [
            _tiles(),
            if (_pin != null) MarkerLayer(markers: [_marker(_pin!, Icons.home, Colors.red)]),
            _attribution,
          ],
        ),
        Positioned(
          left: 12,
          right: 12,
          top: 12,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Text(_locating ? 'กำลังหาตำแหน่งของคุณ...' : 'แตะบนแผนที่ตรงบ้านของคุณ'),
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 96,
          child: FloatingActionButton.small(
            heroTag: 'locate',
            onPressed: _locating ? null : _locate,
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FilledButton(
          onPressed: _pin == null ? null : () => Navigator.pop(context, _pin),
          child: const Text('ใช้ตำแหน่งนี้'),
        ),
      ),
    ),
  );
}
