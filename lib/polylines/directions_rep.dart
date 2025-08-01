import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:grad02/private/private.dart';
import 'package:grad02/station_model.dart';
import 'directions.dart';
import 'location_manager.dart';

const String google_API_Key = googleApiKey;

class DirectionsRep {
  final Dio _dio = Dio();
  Set<Polyline> polylines = {};
  Function(Set<Polyline>)? onPolylinesUpdated;
  GoogleMapController? mapController;

  DirectionsRep({this.onPolylinesUpdated});

  // Your base URL and API key (make sure these are defined)
  static const String _baseURL =
      'https://maps.googleapis.com/maps/api/directions/json';

  void setMapController(GoogleMapController controller) {
    mapController = controller;
  }

  Future<Directions?> getDirections({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      // Validate coordinates
      if (origin.latitude == 0.0 && origin.longitude == 0.0) {
        print('Invalid origin coordinates');
        return null;
      }

      if (destination.latitude == 0.0 && destination.longitude == 0.0) {
        print('Invalid destination coordinates');
        return null;
      }

      // Debug: Print the exact URL being called
      final String requestUrl =
          '$_baseURL?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=$google_API_Key&mode=driving&units=metric';
      print('Full Request URL: $requestUrl');

      print(
        'Getting directions from ${origin.latitude},${origin.longitude} to ${destination.latitude},${destination.longitude}',
      );

      final response = await _dio.get(
        _baseURL,
        queryParameters: {
          'origin': '${origin.latitude},${origin.longitude}',
          'destination': '${destination.latitude},${destination.longitude}',
          'key': google_API_Key,
          'mode': 'driving',
          'units': 'metric',
        },
      );

      print('API Response Status: ${response.statusCode}');
      print('API Response Data: ${response.data}');

      if (response.statusCode == 200) {
        try {
          return Directions.fromMap(response.data);
        } catch (e) {
          print('Error parsing directions response: $e');
          return null;
        }
      } else {
        print('API request failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Network error getting directions: $e');
      return null;
    }
  }

  double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    double lat1Rad = point1.latitude * (pi / 180);
    double lat2Rad = point2.latitude * (pi / 180);
    double deltaLatRad = (point2.latitude - point1.latitude) * (pi / 180);
    double deltaLngRad = (point2.longitude - point1.longitude) * (pi / 180);

    double a =
        sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) *
            cos(lat2Rad) *
            sin(deltaLngRad / 2) *
            sin(deltaLngRad / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c; // Distance in kilometers
  }

  Station? findNearestStation(LatLng currentLocation, List<Station> stations) {
    if (stations.isEmpty) return null;

    // Filter valid charging stations - handle null type values
    List<Station> validStations =
        stations.where((station) {
          return station.type == StationType.chargingStation &&
              station.locationCoords.latitude >= -90.0 &&
              station.locationCoords.latitude <= 90.0 &&
              station.locationCoords.longitude >= -180.0 &&
              station.locationCoords.longitude <= 180.0;
        }).toList();

    if (validStations.isEmpty) {
      print('No valid charging stations found');
      return null;
    }

    try {
      Station nearestStation = validStations.first;
      double minDistance = calculateDistance(
        currentLocation,
        validStations.first.locationCoords,
      );

      for (Station station in validStations) {
        double distance = calculateDistance(
          currentLocation,
          station.locationCoords,
        );
        if (distance < minDistance) {
          minDistance = distance;
          nearestStation = station;
        }
      }

      return nearestStation;
    } catch (e) {
      print('Error in findNearestStation: $e');
      return null;
    }
  }

  Future<void> findNearestStationAndCreatePolyline() async {
    try {
      print('=== STARTING findNearestStationAndCreatePolyline ===');

      // Get current location
      LatLng currentLocation = LatLng(
        LocationManager.shared.currentPos?.latitude ?? 0.0,
        LocationManager.shared.currentPos?.longitude ?? 0.0,
      );

      print('Current location: $currentLocation');

      if (currentLocation.latitude == 0.0 && currentLocation.longitude == 0.0) {
        print('Current location not available');
        return;
      }

      // Add validation for evStations list
      if (evStations.isEmpty) {
        print('ERROR: evStations list is null or empty');
        return;
      }

      print('Available stations count: ${evStations.length}');

      // Debug: Check station types
      for (int i = 0; i < evStations.length; i++) {
        Station station = evStations[i];
        print(
          'Station $i: ${station.stationName}, type: ${station.type}, type is null: ${station.type == null}',
        );
      }

      // Find nearest station with better error handling
      Station? nearestStation = findNearestStation(currentLocation, evStations);

      if (nearestStation == null) {
        print('No valid stations available');
        return;
      }

      print('Nearest station found: ${nearestStation.stationName}');
      print('Station location: ${nearestStation.locationCoords}');
      print('Station type: ${nearestStation.type}');

      // Validate station location coordinates
      if ((nearestStation.locationCoords.latitude == 0.0 &&
          nearestStation.locationCoords.longitude == 0.0)) {
        print('ERROR: Invalid station coordinates');
        return;
      }

      // Get directions
      Directions? directions = await getDirections(
        origin: currentLocation,
        destination: nearestStation.locationCoords,
      );

      if (directions != null) {
        print('Directions received, creating polyline...');
        print('Polyline points count: ${directions.polylinePoints.length}');

        // Create the polyline
        Polyline? routePolyline = await getPolylineData(
          directions,
          nearestStation,
        );

        if (routePolyline != null) {
          print('Polyline created successfully');

          // Clear and add polyline
          polylines.clear();
          polylines.add(routePolyline);

          print('Polyline added to set. Set size: ${polylines.length}');

          // Call the callback
          if (onPolylinesUpdated != null) {
            print('Calling onPolylinesUpdated callback...');
            onPolylinesUpdated!(polylines);
            print('Callback called successfully');
          }

          // Move camera to show the route
          await _fitCameraToShowRoute(routePolyline);

          print('Total distance: ${directions.totalDistance}');
          print('Total duration: ${directions.totalDuration}');
        } else {
          print('ERROR: Failed to create polyline');
        }
      } else {
        print('ERROR: Could not get directions to nearest station');
      }
    } catch (e, stackTrace) {
      print('ERROR in findNearestStationAndCreatePolyline: $e');
      print('Stack trace: $stackTrace');

      // More detailed error analysis
      if (e.toString().contains('StationType')) {
        print('DETAILED ERROR ANALYSIS:');
        print('This is a StationType related error. Checking evStations...');

        for (int i = 0; i < evStations.length; i++) {
          try {
            Station station = evStations[i];
            print(
              'Station $i check: name=${station.stationName}, type=${station.type}',
            );

            // Try to access the type property safely
            bool isCharging = station.type == StationType.chargingStation;
            print('Station $i type comparison successful: $isCharging');
          } catch (stationError) {
            print('ERROR with station $i: $stationError');
            // Fix this station
            Station problematicStation = evStations[i];
            evStations[i] = Station(
              stationName: problematicStation.stationName,
              address: problematicStation.address,
              thumbNail: problematicStation.thumbNail,
              locationCoords: problematicStation.locationCoords,
              type: StationType.chargingStation,
              userId: problematicStation.userId,
            );
            print('Fixed station $i');
          }
        }
      }
    }
  }

  // Add this method to your DirectionsRep class in directions_rep.dart
  Station? findNearestAnyLocation(LatLng currentLocation) {
    // Get all available stations including home
    List<Station> allStations = getAllAvailableStations();

    if (allStations.isEmpty) return null;

    // Filter valid stations (both charging stations and home locations)
    List<Station> validStations =
        allStations.where((station) {
          return (station.type == StationType.chargingStation ||
                  station.type == StationType.homeLocation) &&
              station.locationCoords.latitude >= -90.0 &&
              station.locationCoords.latitude <= 90.0 &&
              station.locationCoords.longitude >= -180.0 &&
              station.locationCoords.longitude <= 180.0;
        }).toList();

    if (validStations.isEmpty) {
      print('No valid locations found (charging stations or home)');
      return null;
    }

    try {
      Station nearestStation = validStations.first;
      double minDistance = calculateDistance(
        currentLocation,
        validStations.first.locationCoords,
      );

      for (Station station in validStations) {
        double distance = calculateDistance(
          currentLocation,
          station.locationCoords,
        );
        if (distance < minDistance) {
          minDistance = distance;
          nearestStation = station;
        }
      }

      print(
        'Nearest location found: ${nearestStation.stationName} (Type: ${nearestStation.type})',
      );
      print('Distance: ${minDistance.toStringAsFixed(2)} km');

      return nearestStation;
    } catch (e) {
      print('Error in findNearestAnyLocation: $e');
      return null;
    }
  }

  // Add this method to create polyline to any nearest location (including home)
  Future<void> findNearestLocationAndCreatePolyline() async {
    try {
      print(
        '=== STARTING findNearestLocationAndCreatePolyline (including home) ===',
      );

      // Get current location
      LatLng currentLocation = LatLng(
        LocationManager.shared.currentPos?.latitude ?? 0.0,
        LocationManager.shared.currentPos?.longitude ?? 0.0,
      );

      print('Current location: $currentLocation');

      if (currentLocation.latitude == 0.0 && currentLocation.longitude == 0.0) {
        print('Current location not available');
        return;
      }

      // Find nearest location (charging station OR home)
      Station? nearestLocation = findNearestAnyLocation(currentLocation);

      if (nearestLocation == null) {
        print('No valid locations available');
        return;
      }

      print('Nearest location found: ${nearestLocation.stationName}');
      print('Location type: ${nearestLocation.type}');
      print('Location coordinates: ${nearestLocation.locationCoords}');

      // Validate location coordinates
      if ((nearestLocation.locationCoords.latitude == 0.0 &&
          nearestLocation.locationCoords.longitude == 0.0)) {
        print('ERROR: Invalid location coordinates');
        return;
      }

      // Get directions
      Directions? directions = await getDirections(
        origin: currentLocation,
        destination: nearestLocation.locationCoords,
      );

      if (directions != null) {
        print('Directions received, creating polyline...');
        print('Polyline points count: ${directions.polylinePoints.length}');

        // Create the polyline with different colors for different types
        Color polylineColor =
            nearestLocation.isHomeLocation ? Colors.purple : Colors.purple;

        Polyline? routePolyline = await getPolylineData(
          directions,
          nearestLocation,
          color: polylineColor,
        );

        if (routePolyline != null) {
          print('Polyline created successfully');

          // Clear and add polyline
          polylines.clear();
          polylines.add(routePolyline);

          print('Polyline added to set. Set size: ${polylines.length}');

          // Call the callback
          if (onPolylinesUpdated != null) {
            print('Calling onPolylinesUpdated callback...');
            onPolylinesUpdated!(polylines);
            print('Callback called successfully');
          }

          // Move camera to show the route
          await _fitCameraToShowRoute(routePolyline);

          print('Total distance: ${directions.totalDistance}');
          print('Total duration: ${directions.totalDuration}');

          String locationType =
              nearestLocation.isHomeLocation
                  ? "home location"
                  : "charging station";
          print(
            'Route created to nearest $locationType: ${nearestLocation.stationName}',
          );
        } else {
          print('ERROR: Failed to create polyline');
        }
      } else {
        print('ERROR: Could not get directions to nearest location');
      }
    } catch (e, stackTrace) {
      print('ERROR in findNearestLocationAndCreatePolyline: $e');
      print('Stack trace: $stackTrace');
    }
  }

  Station? findNearestLocation(
    LatLng currentLocation,
    List<Station> allStations, {
    bool includeHome = false,
  }) {
    if (allStations.isEmpty) return null;

    List<Station> availableStations =
        includeHome
            ? allStations
                .where((station) => station.type != null)
                .toList() // Include all types but filter null
            : allStations
                .where((station) => station.isChargingStation)
                .toList(); // Only charging stations

    if (availableStations.isEmpty) return null;

    Station nearestStation = availableStations.first;
    double minDistance = calculateDistance(
      currentLocation,
      availableStations.first.locationCoords,
    );

    for (Station station in availableStations) {
      double distance = calculateDistance(
        currentLocation,
        station.locationCoords,
      );
      if (distance < minDistance) {
        minDistance = distance;
        nearestStation = station;
      }
    }

    return nearestStation;
  }

  Future<void> adjustCameraToShowRoute(
    Directions directions,
    GoogleMapController? mapController,
  ) async {
    if (mapController == null) return;

    try {
      // Use the bounds from the directions to fit the camera
      await mapController.animateCamera(
        CameraUpdate.newLatLngBounds(
          directions.bounds,
          100.0, // padding
        ),
      );
      print('Camera adjusted to show full route');
    } catch (e) {
      print('Error adjusting camera: $e');
    }
  }

  List<Station> getAllAvailableStations() {
    List<Station> allStations = List.from(evStations);

    // Add home location if it exists
    if (userHomeStation != null) {
      print(
        'Adding home station to available stations: ${userHomeStation!.stationName}',
      );
      print('Home station coordinates: ${userHomeStation!.locationCoords}');
      print('Home station type: ${userHomeStation!.type}');
      allStations.add(userHomeStation!);
    } else {
      print('No home station available');
    }

    print('Total available stations (including home): ${allStations.length}');
    return allStations;
  }

  Future<Polyline?> getPolylineData(
    Directions directions,
    Station targetStation, {
    Color color = Colors.purple,
  }) async {
    try {
      if (directions.polylinePoints.isEmpty) {
        print('No polyline points available');
        return null;
      }

      List<LatLng> polylineCoordinates =
          directions.polylinePoints
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();

      print('Creating polyline with ${polylineCoordinates.length} points');
      print('First coordinate: ${polylineCoordinates.first}');
      print('Last coordinate: ${polylineCoordinates.last}');

      String polylineId =
          targetStation.isHomeLocation
              ? 'route_to_home'
              : 'route_to_${targetStation.stationName.replaceAll(' ', '_').toLowerCase()}';

      return Polyline(
        polylineId: PolylineId(polylineId),
        points: polylineCoordinates,
        color: color,
        width: 5,
        geodesic: true,
      );
    } catch (e) {
      print('Error creating polyline: $e');
      return null;
    }
  }

  void clearPolylines() {
    polylines.clear();
    onPolylinesUpdated?.call(polylines);
  }

  Future<Station?> getNearestStation() async {
    LatLng currentLocation = LatLng(
      LocationManager.shared.currentPos?.latitude ?? 0.0,
      LocationManager.shared.currentPos?.longitude ?? 0.0,
    );
    if (currentLocation.latitude == 0.0 && currentLocation.longitude == 0.0) {
      return null;
    }
    return findNearestStation(currentLocation, evStations);
  }

  Future<void> _fitCameraToShowRoute(Polyline polyline) async {
    if (mapController == null || polyline.points.isEmpty) return;

    try {
      // Calculate bounds that include all points of the polyline
      double minLat = polyline.points.first.latitude;
      double maxLat = polyline.points.first.latitude;
      double minLng = polyline.points.first.longitude;
      double maxLng = polyline.points.first.longitude;

      for (LatLng point in polyline.points) {
        minLat = min(minLat, point.latitude);
        maxLat = max(maxLat, point.latitude);
        minLng = min(minLng, point.longitude);
        maxLng = max(maxLng, point.longitude);
      }

      // Create bounds
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );

      // Animate camera to show the full route
      await mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100.0),
      );

      print('Camera fitted to show route to nearest station');
    } catch (e) {
      print('Error fitting camera to route: $e');
    }
  }
}
