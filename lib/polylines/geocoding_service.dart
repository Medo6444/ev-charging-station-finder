import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:grad02/private/private.dart';

class GeocodingService {
  static final Dio _dio = Dio();
  static const String _apiKey = googleApiKey; // Use your existing API key

  static Future<Map<String, String>?> getAddressFromCoordinates(LatLng coordinates) async {
    try {
      final String url = 'https://maps.googleapis.com/maps/api/geocode/json';

      final response = await _dio.get(
        url,
        queryParameters: {
          'latlng': '${coordinates.latitude},${coordinates.longitude}',
          'key': _apiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final result = data['results'][0];

          String streetName = '';
          String formattedAddress = result['formatted_address'] ?? '';

          // Extract street name from address components
          for (var component in result['address_components']) {
            final types = component['types'] as List;
            if (types.contains('route')) {
              streetName = component['long_name'] ?? '';
              break;
            }
          }

          // If no street name found, try to extract from formatted address
          if (streetName.isEmpty) {
            final addressParts = formattedAddress.split(',');
            if (addressParts.isNotEmpty) {
              streetName = addressParts[0].trim();
            }
          }

          return {
            'streetName': streetName,
            'formattedAddress': formattedAddress,
          };
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // Alternative method using a simpler approach without API key (less accurate)
  static Map<String, String> getSimpleAddressInfo(LatLng coordinates) {
    // This is a fallback method that creates a simple address format
    // In a real app, you should use the Google Geocoding API above
    return {
      'streetName': 'Location at ${coordinates.latitude.toStringAsFixed(4)}, ${coordinates.longitude.toStringAsFixed(4)}',
      'formattedAddress': 'Lat: ${coordinates.latitude.toStringAsFixed(6)}, Lng: ${coordinates.longitude.toStringAsFixed(6)}',
    };
  }
}