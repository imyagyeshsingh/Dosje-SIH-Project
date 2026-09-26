import '../error/app_exception.dart';

class LocationDisabledException extends AppException {
  LocationDisabledException([super.message = 'Location services are disabled on this device']);
}

class LocationPermissionDeniedException extends AppException {
  LocationPermissionDeniedException([super.message = 'Location permission denied']);
}

class GnssLocation {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime timestamp;
  final bool isLocked;

  const GnssLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.timestamp,
    this.isLocked = true,
  });

  String get formattedCoords =>
      '${latitude.toStringAsFixed(4)}° N, ${longitude.toStringAsFixed(4)}° E';
}

abstract class LocationService {
  Future<GnssLocation> getCurrentLocation();
  Future<bool> isLocationServiceEnabled();
  Future<bool> hasPermission();
  Future<bool> requestPermission();
}

class DefaultLocationService implements LocationService {
  double _latitude;
  double _longitude;
  double _accuracyMeters;
  bool _hasPermission;
  bool _serviceEnabled;

  DefaultLocationService({
    double latitude = 27.1982,
    double longitude = 78.0059,
    double accuracyMeters = 2.8,
    bool hasPermission = true,
    bool serviceEnabled = true,
  })  : _latitude = latitude,
        _longitude = longitude,
        _accuracyMeters = accuracyMeters,
        _hasPermission = hasPermission,
        _serviceEnabled = serviceEnabled;

  void setMockLocation({
    required double latitude,
    required double longitude,
    double accuracyMeters = 2.8,
  }) {
    _latitude = latitude;
    _longitude = longitude;
    _accuracyMeters = accuracyMeters;
  }

  void setPermission(bool granted) {
    _hasPermission = granted;
  }

  void setServiceEnabled(bool enabled) {
    _serviceEnabled = enabled;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => _serviceEnabled;

  @override
  Future<bool> hasPermission() async => _hasPermission;

  @override
  Future<bool> requestPermission() async => _hasPermission;

  @override
  Future<GnssLocation> getCurrentLocation() async {
    if (!_serviceEnabled) {
      throw LocationDisabledException();
    }
    if (!_hasPermission) {
      throw LocationPermissionDeniedException();
    }
    return GnssLocation(
      latitude: _latitude,
      longitude: _longitude,
      accuracyMeters: _accuracyMeters,
      timestamp: DateTime.now(),
      isLocked: true,
    );
  }
}
