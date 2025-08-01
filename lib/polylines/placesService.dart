import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:grad02/private/private.dart';
import 'locationSearchBar.dart';

class PlacesService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place';

  // Get autocomplete predictions
  static Future<List<PlacePrediction>> getAutocompletePredictions(
      String query, {
        String? countryCode = 'eg', // Default to Egypt
        List<String> types = const ['geocode'],
      }) async {
    try {
      final String url = '$_baseUrl/autocomplete/json'
          '?input=${Uri.encodeComponent(query)}'
          '&key=$googleApiKey'
          '&types=${types.join('|')}'
          '${countryCode != null ? '&components=country:$countryCode' : ''}';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          return (data['predictions'] as List)
              .map((prediction) => PlacePrediction.fromJson(prediction))
              .toList();
        } else {
          return [];
        }
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }
  static Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    try {
      final String url = '$_baseUrl/details/json'
          '?place_id=$placeId'
          '&key=$googleApiKey'
          '&fields=geometry,name,formatted_address,types';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          return PlaceDetails.fromJson(data['result']);
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // Search nearby places (useful for finding charging stations)
  static Future<List<PlaceDetails>> searchNearby(
      LatLng location,
      String keyword, {
        int radius = 5000, // 5km default
        List<String> types = const [],
      }) async {
    try {
      String url = '$_baseUrl/nearbysearch/json'
          '?location=${location.latitude},${location.longitude}'
          '&radius=$radius'
          '&key=$googleApiKey';

      if (keyword.isNotEmpty) {
        url += '&keyword=${Uri.encodeComponent(keyword)}';
      }

      if (types.isNotEmpty) {
        url += '&type=${types.first}'; // API only accepts one type for nearby search
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          return (data['results'] as List)
              .map((place) => PlaceDetails.fromJson(place))
              .toList();
        } else {
          return [];
        }
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // Text search for places
  static Future<List<PlaceDetails>> textSearch(String query) async {
    try {
      final String url = '$_baseUrl/textsearch/json'
          '?query=${Uri.encodeComponent(query)}'
          '&key=$googleApiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          return (data['results'] as List)
              .map((place) => PlaceDetails.fromJson(place))
              .toList();
        } else {
          return [];
        }
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }
}

class PlaceDetails {
  final String? placeId;
  final String name;
  final String formattedAddress;
  final LatLng location;
  final List<String> types;
  final double? rating;

  PlaceDetails({
    this.placeId,
    required this.name,
    required this.formattedAddress,
    required this.location,
    required this.types,
    this.rating,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'];
    final location = geometry['location'];

    return PlaceDetails(
      placeId: json['place_id'],
      name: json['name'] ?? 'Unknown',
      formattedAddress: json['formatted_address'] ?? json['vicinity'] ?? '',
      location: LatLng(
        location['lat']?.toDouble() ?? 0.0,
        location['lng']?.toDouble() ?? 0.0,
      ),
      types: List<String>.from(json['types'] ?? []),
      rating: json['rating']?.toDouble(),
    );
  }
}