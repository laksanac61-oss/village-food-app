import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Map center when we know nothing else (Bangkok). Users move the pin from here.
const fallbackCenter = LatLng(13.7563, 100.5018);

/// Current device position, or null if the user refused or GPS is off.
Future<LatLng?> currentLocation() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return LatLng(p.latitude, p.longitude);
  } catch (_) {
    return null;
  }
}

/// Google Maps directions link; opens the Maps app on phones.
Uri directionsUrl(double lat, double lng) =>
    Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
