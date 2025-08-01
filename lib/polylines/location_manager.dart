import 'dart:async';
import 'dart:math' as Math;
import 'package:fbroadcast/fbroadcast.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:grad02/common/glob.dart';
import 'package:grad02/common/service_call.dart';
import 'package:grad02/common/socket_manager.dart';

class LocationManager {
  static final LocationManager sigleton = LocationManager._internal();
  LocationManager._internal();
  static LocationManager get shared => sigleton;

  Position? currentPos;
  double carDegree = 0.0;

  Future<void> getLocaitonUpdates() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint(" Location service are disabled.");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint(" Location service are denied.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint(
          " Location permission are permanently denied, we cannot request permission");
      return;
    }

    const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 15);

    StreamSubscription<Position> _ =
    Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      carDegree = calculateDegrees(
          LatLng(currentPos?.latitude ?? 0.0, currentPos?.longitude ?? 0.0),
          LatLng(position.latitude, position.longitude));
      currentPos = position;
      apiCarUpdateLocation();
      FBroadcast.instance().broadcast("update_location", value: position);
      debugPrint(position.toString());
    });
  }

  static double calculateDegrees(LatLng startPoint, LatLng endPoint) {
    final double startLat = toRadians(startPoint.latitude);
    final double startLng = toRadians(startPoint.longitude);
    final double endLat = toRadians(endPoint.latitude);
    final double endLng = toRadians(endPoint.longitude);

    final double deltaLng = endLng - startLng;

    final double y = Math.sin(deltaLng) * Math.cos(endLat);
    final double x = Math.cos(startLat) * Math.sin(endLat) -
        Math.sin(startLat) * Math.cos(endLat) * Math.cos(deltaLng);

    final double bearing = Math.atan2(y, x);
    return (toDegrees(bearing) + 360) % 360;
  }

  static double toRadians(double degrees) {
    return degrees * (Math.pi / 180.0);
  }

  static double toDegrees(double radians) {
    return radians * (180.0 / Math.pi);
  }

  //TODO: ApiCalling

  void apiCarUpdateLocation() {
    // Only send updates if we have a valid position
    if (currentPos == null) {
      if (kDebugMode) {
        print("⏳ No current position available for update");
      }
      return;
    }

    if (carDegree.isNaN || carDegree.isInfinite) {
      carDegree = 0.0;
      if (kDebugMode) {
        print("⚠️ Fixed invalid carDegree, set to 0.0");
      }
    }

    // Enhanced socket connection check
    final socketConnected = SocketManager.shared.isConnected;
    final socketId = SocketManager.shared.socket?.id;

    if (kDebugMode) {
      print("=== LOCATION UPDATE CHECK ===");
      print("Socket connected: $socketConnected");
      print("Socket ID: $socketId");
      print("User UUID: ${ServiceCall.userUUID}");
      print("Current position: ${currentPos?.latitude}, ${currentPos?.longitude}");
      print("===========================");
    }

    if (!socketConnected || socketId == null || socketId.isEmpty) {
      if (kDebugMode) {
        print("⚠️ Cannot send location update - socket not ready");
      }
      return;
    }

    if (ServiceCall.userUUID.isEmpty) {
      if (kDebugMode) {
        print("⚠️ Cannot send location update - user UUID is empty");
      }
      return;
    }

    final updateData = {
      "uuid": ServiceCall.userUUID,
      "lat": currentPos!.latitude.toString(),
      "long": currentPos!.longitude.toString(),
      "degree": carDegree.toString(),
      "socket_id": socketId,
    };

    if (kDebugMode) {
      print("📍 Sending location update to: ${SVKey.svCarUpdateLocation}");
      print("Data: $updateData");
    }

    ServiceCall.post(updateData, SVKey.svCarUpdateLocation, (responseObj) async {
      if (responseObj[KKey.status] == "1") {
        if (kDebugMode) {
          print("✅ Location update successful");
        }
      } else {
        if (kDebugMode) {
          print("❌ Location update failed: ${responseObj[KKey.message]}");
        }
      }
    }, (error) async {
      if (kDebugMode) {
        print("❌ Location update HTTP error: $error");
      }
    });
  }

// Also update the initLocation method:
  void initLocation() {
    if (kDebugMode) {
      print("🚀 LocationManager initLocation called");
    }

    // Start location services first, then wait for socket
    _startLocationServicesFirst();
  }

  void _startLocationServicesFirst() async {
    try {
      // Get initial location permission and start location updates
      await getLocationUpdates();

      // Then wait for socket connection
      _waitForSocketAndStartLocationUpdates();
    } catch (e) {
      if (kDebugMode) {
        print("❌ Error starting location services: $e");
      }
      // Retry after delay
      Future.delayed(Duration(seconds: 5), () {
        _startLocationServicesFirst();
      });
    }
  }

  void _waitForSocketAndStartLocationUpdates() {
    final isConnected = SocketManager.shared.isConnected;
    final hasSocketId = SocketManager.shared.socket?.id != null;

    if (kDebugMode) {
      print("⏳ Checking socket status for location transmission:");
      print("Connected: $isConnected");
      print("Has Socket ID: $hasSocketId");
      print("Socket ID: ${SocketManager.shared.socket?.id}");
      print("Current position available: ${currentPos != null}");
    }

    if (isConnected && hasSocketId && currentPos != null) {
      if (kDebugMode) {
        print("✅ Socket is ready and location available, enabling location transmission");
      }
      // Socket is ready, location updates will now be transmitted
      return;
    } else {
      if (kDebugMode) {
        print("⏳ Socket not ready or no location, waiting 8 seconds...");
      }
      // Check again in 8 seconds for cloud deployment
      Future.delayed(Duration(seconds: 8), () {
        _waitForSocketAndStartLocationUpdates();
      });
    }
  }

// Rename and fix the method:
  Future<void> getLocationUpdates() async {
    if (kDebugMode) {
      print("🎯 Starting location updates...");
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint("❌ Location services are disabled.");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint("❌ Location permissions are denied.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint("❌ Location permissions are permanently denied.");
      return;
    }

    const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 15
    );

    if (kDebugMode) {
      print("✅ Starting location stream...");
    }

    StreamSubscription<Position> _ =
    Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {

      // Calculate car degree - IMPROVED VERSION
      if (currentPos != null) {
        double newDegree = calculateDegrees(
            LatLng(currentPos!.latitude, currentPos!.longitude),
            LatLng(position.latitude, position.longitude));

        // Only update degree if the movement is significant (more than 5 meters)
        double distance = Geolocator.distanceBetween(
            currentPos!.latitude,
            currentPos!.longitude,
            position.latitude,
            position.longitude
        );

        if (distance > 5.0) { // Only update rotation for significant movement
          carDegree = newDegree;
          if (kDebugMode) {
            print("📐 Updated car degree: $carDegree (moved ${distance.toStringAsFixed(1)}m)");
          }
        } else {
          if (kDebugMode) {
            print("📐 Keeping previous degree: $carDegree (movement too small: ${distance.toStringAsFixed(1)}m)");
          }
        }
      } else {
        carDegree = 0.0; // Default degree for first position
      }

      currentPos = position;

      if (kDebugMode) {
        print("📍 New position received:");
        print("  Lat: ${position.latitude}");
        print("  Lng: ${position.longitude}");
        print("  Degree: $carDegree");
      }

      // Send update to server
      apiCarUpdateLocation();

      // Broadcast locally for UI updates
      FBroadcast.instance().broadcast("update_location", value: position);

      // NEW: Also broadcast for map updates
      FBroadcast.instance().broadcast("update_my_car", value: {
        'position': position,
        'degree': carDegree
      });

    }, onError: (error) {
      if (kDebugMode) {
        print("❌ Location stream error: $error");
      }
    });
  }
}