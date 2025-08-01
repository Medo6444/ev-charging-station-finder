import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Directions {
  final LatLngBounds bounds;
  final List<PointLatLng> polylinePoints;
  final String totalDistance;
  final String totalDuration;

  bool get isValid {
    return polylinePoints.isNotEmpty &&
        totalDistance.isNotEmpty &&
        totalDuration.isNotEmpty &&
        totalDistance != 'Unknown distance' &&
        totalDuration != 'Unknown duration';
  }

  const Directions({
    required this.bounds,
    required this.polylinePoints,
    required this.totalDistance,
    required this.totalDuration,
  });

  factory Directions.fromMap(Map<String, dynamic> map) {
    try {
      // Check if the response has routes
      if (map['routes'] == null || (map['routes'] as List).isEmpty) {
        throw Exception('No routes found in the response. Status: ${map['status']}');
      }

      // Check the status of the response
      final status = map['status'];
      if (status != 'OK') {
        String errorMessage = 'Directions API Error: $status';
        if (map['error_message'] != null) {
          errorMessage += ' - ${map['error_message']}';
        }

        // Add more specific error messages
        switch (status) {
          case 'NOT_FOUND':
            errorMessage += ' (One or more locations could not be found)';
            break;
          case 'ZERO_RESULTS':
            errorMessage += ' (No route could be found between the origin and destination)';
            break;
          case 'MAX_WAYPOINTS_EXCEEDED':
            errorMessage += ' (Too many waypoints in the request)';
            break;
          case 'INVALID_REQUEST':
            errorMessage += ' (Invalid request parameters)';
            break;
          case 'OVER_QUERY_LIMIT':
            errorMessage += ' (API query limit exceeded)';
            break;
          case 'REQUEST_DENIED':
            errorMessage += ' (Request denied by the service)';
            break;
          case 'UNKNOWN_ERROR':
            errorMessage += ' (Unknown server error)';
            break;
        }

        throw Exception(errorMessage);
      }

      final data = Map<String, dynamic>.from(map['routes'][0]);

      // Check if bounds exist with better null safety
      final boundsData = data['bounds'];
      if (boundsData == null ||
          boundsData['northeast'] == null ||
          boundsData['southwest'] == null) {
        throw Exception('Route bounds not found in response');
      }

      final northeast = boundsData['northeast'];
      final southwest = boundsData['southwest'];

      // Validate coordinates
      if (northeast['lat'] == null || northeast['lng'] == null ||
          southwest['lat'] == null || southwest['lng'] == null) {
        throw Exception('Invalid coordinate data in bounds');
      }

      final bounds = LatLngBounds(
        southwest: LatLng(
            (southwest['lat'] as num).toDouble(),
            (southwest['lng'] as num).toDouble()
        ),
        northeast: LatLng(
            (northeast['lat'] as num).toDouble(),
            (northeast['lng'] as num).toDouble()
        ),
      );

      String distance = 'Unknown distance';
      String duration = 'Unknown duration';

      // Better handling of legs data
      final legs = data['legs'];
      if (legs != null && legs is List && legs.isNotEmpty) {
        final leg = legs[0];
        if (leg != null && leg is Map) {
          distance = leg['distance']?['text']?.toString() ?? 'Unknown distance';
          duration = leg['duration']?['text']?.toString() ?? 'Unknown duration';
        }
      }

      // Check if overview_polyline exists with better validation
      final overviewPolyline = data['overview_polyline'];
      if (overviewPolyline == null || overviewPolyline['points'] == null) {
        throw Exception('Polyline data not found in response');
      }

      final polylineString = overviewPolyline['points'];
      if (polylineString == null || polylineString.toString().isEmpty) {
        throw Exception('Empty polyline data');
      }

      List<PointLatLng> polylinePoints = [];
      try {
        polylinePoints = PolylinePoints().decodePolyline(polylineString.toString());

        // Validate that we actually got points
        if (polylinePoints.isEmpty) {
          throw Exception('Decoded polyline contains no points');
        }
      } catch (e) {
        throw Exception('Failed to decode polyline: $e');
      }

      return Directions(
        bounds: bounds,
        polylinePoints: polylinePoints,
        totalDistance: distance,
        totalDuration: duration,
      );

    } catch (e) {
      // Re-throw with additional context
      if (e is Exception) {
        rethrow;
      } else {
        throw Exception('Unexpected error parsing directions: $e');
      }
    }
  }
}