import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

class Ward {
  final String id;
  final String name;
  final int number;
  final String? zoneId;
  final String? zoneName;
  final String? representativeName;
  final List<String> representativePhone;
  /// Councillor / elected rep email (API: representative_email).
  final String? representativeEmail;
  /// Party name from party_id or legacy field (API: representative_party).
  final String? representativeParty;
  final double? centroidLat;
  final double? centroidLng;
  final double? minLat;
  final double? maxLat;
  final double? minLng;
  final double? maxLng;

  const Ward({
    required this.id,
    required this.name,
    required this.number,
    this.zoneId,
    this.zoneName,
    this.representativeName,
    this.representativePhone = const [],
    this.representativeEmail,
    this.representativeParty,
    this.centroidLat,
    this.centroidLng,
    this.minLat,
    this.maxLat,
    this.minLng,
    this.maxLng,
  });

  factory Ward.fromJson(Map<String, dynamic> json) {
    return Ward(
      id: json['id'],
      name: json['name'],
      number: json['number'],
      zoneId: json['zone_id'],
      zoneName: json['zone_name'],
      representativeName: json['representative_name'] as String?,
      representativePhone: (json['representative_phone'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      representativeEmail: json['representative_email'] as String?,
      representativeParty: json['representative_party'] as String?,
      centroidLat: (json['centroid_lat'] as num?)?.toDouble(),
      centroidLng: (json['centroid_lng'] as num?)?.toDouble(),
      minLat: (json['min_lat'] as num?)?.toDouble(),
      maxLat: (json['max_lat'] as num?)?.toDouble(),
      minLng: (json['min_lng'] as num?)?.toDouble(),
      maxLng: (json['max_lng'] as num?)?.toDouble(),
    );
  }

  LatLng? get centroid {
    if (centroidLat != null && centroidLng != null) {
      return LatLng(centroidLat!, centroidLng!);
    }
    return null;
  }

  bool get hasBounds =>
      minLat != null && maxLat != null && minLng != null && maxLng != null;

  LatLngBounds? get bounds {
    if (!hasBounds) return null;
    return LatLngBounds(
      LatLng(minLat!, minLng!),
      LatLng(maxLat!, maxLng!),
    );
  }
}
