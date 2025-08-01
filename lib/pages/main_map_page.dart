import 'dart:async';
import 'dart:math' as math;
import 'package:fbroadcast/fbroadcast.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:grad02/pages/side_menu.dart';
import 'package:grad02/station_model.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:grad02/polylines/location_manager.dart';
import 'package:socket_io_client/socket_io_client.dart';
import '../common/glob.dart';
import '../common/service_call.dart';
import '../common/socket_manager.dart';
import 'package:grad02/polylines/directions_rep.dart';
import '../polylines/directions.dart';
import '../polylines/geocoding_service.dart';
import '../polylines/home_location_service.dart';
import '../polylines/locationSearchBar.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();
  GoogleMapController? mapController;
  Set<Polyline> polylines = {};
  Set<Marker> markers = {};
  late DirectionsRep stationFinder;
  bool _isHomeLocationMode = false;
  LatLng? _homeLocationPin;
  Marker? _homeLocationMarker;
  bool _isFullyInitialized = false;
  int? _lastCarJoinTime;
  bool _isInitialized = false;
  final TextEditingController _socController = TextEditingController();
  int? storedSOC;
  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(30.0076964, 31.2428155),
    zoom: 12,
  );
  late LatLng currentPosition;
  late PageController _pageController;
  final Map<String, Marker> usersCarArr = {};
  List<Marker> stationMarkers = [];
  BitmapDescriptor? iconCar;
  BitmapDescriptor? iconStation;
  BitmapDescriptor? iconHome;
  bool iconsLoaded = false;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  bool _isMenuOpen = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
    ensureStationTypesAreSet();
    _loadSavedHomeLocation();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: -350.0, end: -83).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    FBroadcast.instance().register("update_my_car", (value, callback) {
      if (mounted && iconsLoaded) {
        updateMyCarLocation();
      }
    });
    stationFinder = DirectionsRep(
      onPolylinesUpdated: (Set<Polyline> newPolylines) {
        setState(() {
          polylines = newPolylines;
        });
      },
    );
    _pageController = PageController(initialPage: 1, viewportFraction: 0.8);
    currentPosition = LatLng(
      LocationManager.shared.currentPos?.latitude ?? 0.0,
      LocationManager.shared.currentPos?.longitude ?? 0.0,
    );
    DefaultAssetBundle.of(
      context,
    ).loadString('assets/theme/dark_theme.json').then((thisValue) {
      _themeformap = thisValue;
    });
    _loadIcons().then((_) {
      _setupSocketListeners();
      Future.delayed(Duration(seconds: 3), () {
        apiCarJoin();
      });
      _startConnectionMonitoring();
    });
  }

  Future<void> _initializeApp() async {
    if (_isInitialized) return;

    try {
      _initializeUIComponents();
      await _loadIcons();
      await _initializeLocationServices();
      await _initializeSocketConnection();

      Future.delayed(Duration(seconds: 15), () {
        if (mounted && iconsLoaded) {
          if (SocketManager.shared.isConnected) {
            _joinCarTracking();
          } else {
            Future.delayed(Duration(seconds: 10), () {
              if (mounted && SocketManager.shared.isConnected) {
                _joinCarTracking();
              }
            });
          }
        }
      });

      _initializeStationServices();
      _isInitialized = true;
    } catch (e) {
      debugPrint('❌ App initialization failed: $e');
    }
  }

  void updateMyCarLocation() {
    if (!iconsLoaded || iconCar == null) {
      debugPrint('⏳ Icons not loaded, skipping my car update');
      return;
    }

    final currentPos = LocationManager.shared.currentPos;
    if (currentPos == null) {
      debugPrint('⚠️ No current position available for my car marker');
      return;
    }

    if (ServiceCall.userUUID.isEmpty) {
      debugPrint('⚠️ User UUID is empty, cannot create my car marker');
      return;
    }

    try {
      // ADD THIS: Validate degree
      double degree = LocationManager.shared.carDegree;
      if (degree.isNaN || degree.isInfinite || degree < 0 || degree >= 360) {
        degree = 0.0;
        debugPrint('⚠️ Fixed invalid degree for my car, set to 0.0');
      }

      final myCarMarker = Marker(
        markerId: MarkerId('my_car_${ServiceCall.userUUID}'),
        position: LatLng(currentPos.latitude, currentPos.longitude),
        icon: iconCar!,
        rotation: degree,
        // Use validated degree
        anchor: const Offset(0.5, 0.5),
        infoWindow: InfoWindow(
          title: 'My Car',
          snippet:
              'Current location - ${DateTime.now().toString().substring(11, 19)} - ${degree.toStringAsFixed(1)}°', // ADD DEGREE INFO
        ),
      );

      // Store in a separate variable for your own car
      setState(() {
        usersCarArr['my_car_${ServiceCall.userUUID}'] = myCarMarker;
      });

      debugPrint(
        '✅ Updated my car marker at ${currentPos.latitude}, ${currentPos.longitude}, degree: $degree',
      );
    } catch (e) {
      debugPrint('❌ Error updating my car marker: $e');
    }
  }

  void _initializeUIComponents() {
    ensureStationTypesAreSet();
    _loadSavedHomeLocation();

    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: -350.0, end: -83).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _pageController = PageController(initialPage: 1, viewportFraction: 0.8);

    currentPosition = LatLng(
      LocationManager.shared.currentPos?.latitude ?? 30.0076964,
      LocationManager.shared.currentPos?.longitude ?? 31.2428155,
    );

    DefaultAssetBundle.of(
      context,
    ).loadString('assets/theme/dark_theme.json').then((thisValue) {
      _themeformap = thisValue;
    });
  }

  Future<void> _initializeLocationServices() async {
    try {
      await _waitForInitialLocation();
      LocationManager.shared.initLocation();
    } catch (e) {
      debugPrint('❌ Location services initialization failed: $e');
    }
  }

  Future<void> _waitForInitialLocation() async {
    int attempts = 0;
    const maxAttempts = 10;

    while (attempts < maxAttempts && mounted) {
      final currentPos = LocationManager.shared.currentPos;
      if (currentPos != null) {
        currentPosition = LatLng(currentPos.latitude, currentPos.longitude);
        return;
      }
      attempts++;
      await Future.delayed(Duration(seconds: 2));
    }
  }

  Future<void> _initializeSocketConnection() async {
    try {
      if (!SocketManager.shared.isInitialized) {
        SocketManager.shared.initSocket();
      }
      await _waitForSocketConnection();
      _setupSocketListeners();
    } catch (e) {
      debugPrint('❌ Socket connection initialization failed: $e');
    }
  }

  Future<void> _waitForSocketConnection() async {
    int attempts = 0;
    const maxAttempts = 25;

    while (attempts < maxAttempts && mounted) {
      if (SocketManager.shared.isConnected) {
        await Future.delayed(Duration(seconds: 2));
        return;
      }
      attempts++;
      await Future.delayed(Duration(seconds: 3));
    }
  }

  void _initializeStationServices() {
    stationFinder = DirectionsRep(
      onPolylinesUpdated: (Set<Polyline> newPolylines) {
        if (mounted) {
          setState(() {
            polylines = newPolylines;
          });
        }
      },
    );
  }

  void _setupSocketListeners() {
    final socket = SocketManager.shared.socket;
    if (socket == null) return;

    socket.off(SVKey.nvCarJoin);
    socket.off(SVKey.nvCarUpdateLocation);
    socket.off('car_removed');
    socket.off('connect');
    socket.off('disconnect');

    socket.onConnect((_) {
      Future.delayed(Duration(seconds: 3), () {
        if (mounted && iconsLoaded) {
          _joinCarTracking();
        }
      });
    });

    socket.onDisconnect((reason) {
      if (mounted) {
        setState(() {
          usersCarArr.clear();
        });
      }
    });

    socket.on(SVKey.nvCarJoin, (data) {
      _handleCarJoinEvent(data);
    });

    socket.on(SVKey.nvCarUpdateLocation, (data) {
      _handleCarUpdateEvent(data);
    });

    socket.on('car_removed', (data) {
      _handleCarRemovedEvent(data);
    });
  }

  void _handleCarJoinEvent(dynamic data) {
    try {
      if (data is Map && data[KKey.status] == "1") {
        final payload = data[KKey.payload];
        if (payload is Map) {
          updateOtherCarLocation(payload);
        }
      }
    } catch (e) {
      debugPrint('❌ Error processing car_join: $e');
    }
  }

  void _handleCarUpdateEvent(dynamic data) {
    try {
      if (data is Map && data[KKey.status] == "1") {
        final payload = data[KKey.payload];
        if (payload is Map) {
          updateOtherCarLocation(payload);
        }
      }
    } catch (e) {
      debugPrint('❌ Error processing car_update_location: $e');
    }
  }

  void _handleCarRemovedEvent(dynamic data) {
    try {
      if (data is Map && data[KKey.status] == "1") {
        final payload = data[KKey.payload];
        if (payload is Map) {
          final String carId = payload["uuid"]?.toString() ?? "";
          if (carId.isNotEmpty && mounted) {
            setState(() {
              usersCarArr.remove(carId);
            });
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error processing car_removed: $e');
    }
  }

  Future<void> _loadIcons() async {
    if (iconsLoaded) return;

    try {
      debugPrint('🎨 Loading custom icons...');

      final List<Future<BitmapDescriptor>> iconFutures = [
        BitmapDescriptor.asset(
          const ImageConfiguration(devicePixelRatio: 3.2),
          "assets/mapicons/car.png",
          width: 40,
          height: 40,
        ),
        BitmapDescriptor.asset(
          const ImageConfiguration(devicePixelRatio: 3.2),
          "assets/mapicons/charging-station.png",
          width: 40,
          height: 40,
        ),
        BitmapDescriptor.asset(
          const ImageConfiguration(devicePixelRatio: 3.2),
          "assets/mapicons/real-estate.png",
          width: 40,
          height: 50,
        ),
      ];

      final List<BitmapDescriptor> loadedIcons = await Future.wait(iconFutures);

      if (mounted) {
        setState(() {
          iconCar = loadedIcons[0];
          iconStation = loadedIcons[1];
          iconHome = loadedIcons[2];
          iconsLoaded = true;
        });

        debugPrint('✅ All custom icons loaded successfully');

        // Initialize all station markers immediately after icons load
        _initializeAllStationMarkers();
      }
    } catch (e) {
      debugPrint('❌ Error loading custom icons, using defaults: $e');
      if (mounted) {
        setState(() {
          iconCar = BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueBlue,
          );
          iconStation = BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          );
          iconHome = BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRed,
          );
          iconsLoaded = true;
        });

        // Initialize all station markers even with default icons
        _initializeAllStationMarkers();
      }
    }
  }

  void _initializeAllStationMarkers() {
    if (!iconsLoaded || iconStation == null) {
      debugPrint('⚠️ Cannot initialize station markers - icons not ready');
      return;
    }

    debugPrint('🏢 Initializing all ${evStations.length} station markers...');

    stationMarkers.clear();

    for (var station in evStations) {
      try {
        final marker = Marker(
          markerId: MarkerId(station.stationName),
          draggable: false,
          infoWindow: InfoWindow(
            title: station.stationName,
            snippet: station.address,
          ),
          position: station.locationCoords,
          icon: iconStation!,
        );

        stationMarkers.add(marker);
        debugPrint('✓ Created marker for: ${station.stationName}');
      } catch (e) {
        debugPrint('❌ Failed to create marker for ${station.stationName}: $e');
      }
    }

    // Add home location marker if available
    if (userHomeStation != null && iconHome != null) {
      try {
        final homeMarker = Marker(
          markerId: MarkerId('home_${userHomeStation!.userId}'),
          draggable: false,
          infoWindow: InfoWindow(
            title: userHomeStation!.stationName,
            snippet: userHomeStation!.address,
          ),
          position: userHomeStation!.locationCoords,
          icon: iconHome!,
        );

        stationMarkers.add(homeMarker);
        debugPrint('✓ Created home location marker');
      } catch (e) {
        debugPrint('❌ Failed to create home marker: $e');
      }
    }

    debugPrint(
      '✅ Initialized ${stationMarkers.length} station markers successfully',
    );

    // Mark as fully initialized
    setState(() {
      _isFullyInitialized = true;
    });
  }

  void _joinCarTracking() {
    if (!iconsLoaded) {
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) _joinCarTracking();
      });
      return;
    }

    if (!SocketManager.shared.isConnected) {
      Future.delayed(Duration(seconds: 3), () {
        if (mounted) _joinCarTracking();
      });
      return;
    }

    if (ServiceCall.userUUID.isEmpty) return;

    final requestData = {
      "uuid": ServiceCall.userUUID,
      "lat": currentPosition.latitude.toString(),
      "long": currentPosition.longitude.toString(),
      "degree": LocationManager.shared.carDegree.toString(),
      "socket_id": SocketManager.shared.socket?.id ?? "",
    };

    ServiceCall.post(
      requestData,
      SVKey.svCarJoin,
      (responseObj) async {
        if (responseObj[KKey.status] == "1") {
          final carsData = responseObj[KKey.payload] as Map? ?? {};
          carsData.forEach((key, value) {
            if (value is Map) {
              final carData = Map<String, dynamic>.from(value);
              if (!carData.containsKey("uuid")) {
                carData['uuid'] = key.toString();
              }
              updateOtherCarLocation(carData);
            }
          });

          if (mounted) {
            setState(() {});
          }
        }
      },
      (error) async {
        debugPrint('❌ Car join failed: $error');
      },
    );
  }

  void updateOtherCarLocation(Map obj) {
    final String carId =
        obj["uuid"]?.toString() ??
        "unknown_${DateTime.now().millisecondsSinceEpoch}";

    if (!iconsLoaded || iconCar == null) {
      debugPrint('⏳ Icons not loaded, skipping car update for $carId');
      return;
    }

    try {
      final double lat = double.tryParse(obj["lat"]?.toString() ?? "0") ?? 0.0;
      final double lng = double.tryParse(obj["long"]?.toString() ?? "0") ?? 0.0;
      double degree = double.tryParse(obj["degree"]?.toString() ?? "0") ?? 0.0;

      // ADD THIS: Validate degree value
      if (degree.isNaN || degree.isInfinite || degree < 0 || degree >= 360) {
        degree = 0.0;
        debugPrint('⚠️ Fixed invalid degree for car $carId, set to 0.0');
      }

      // Validate coordinates
      if (lat == 0.0 && lng == 0.0) {
        debugPrint('⚠️ Invalid coordinates for car $carId');
        return;
      }

      // Skip self-tracking
      if (carId == ServiceCall.userUUID) {
        debugPrint('⏩ Skipping self-tracking for user: $carId');
        return;
      }

      final marker = Marker(
        markerId: MarkerId(carId),
        position: LatLng(lat, lng),
        icon: iconCar!,
        rotation: degree,
        // This should now work properly
        anchor: const Offset(0.5, 0.5),
        infoWindow: InfoWindow(
          title: 'Car $carId',
          snippet:
              'Live tracking - ${DateTime.now().toString().substring(11, 19)} - ${degree.toStringAsFixed(1)}°', // ADD DEGREE TO SNIPPET
        ),
      );

      usersCarArr[carId] = marker;

      if (mounted) {
        setState(() {});
        debugPrint(
          '✅ Updated car marker for $carId at $lat, $lng, degree: $degree',
        );
      }
    } catch (e) {
      debugPrint('❌ Error updating car location for $carId: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    _socController.dispose();
    FBroadcast.instance().unregister("update_my_car");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isFullyInitialized) {
      return Scaffold(
        backgroundColor: Colors.black87,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.greenAccent.shade700,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Loading EV Stations...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Initializing ${evStations.length} charging stations',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }
    // Only call setMarkers if we need to refresh, not on initial load
    if (iconsLoaded && _isFullyInitialized) {
      // Markers are already initialized, just ensure they're up to date
    }

    final Set<Marker> allMarkers = {
      ...Set.from(stationMarkers),
      ...usersCarArr.values,
      ...searchMarkers,
    };

    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        leading: GestureDetector(
          onTap: _isHomeLocationMode ? null : _toggleMenu,
          child: Container(
            margin: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:
                  _isHomeLocationMode
                      ? Colors.grey.shade400
                      : Colors.greenAccent.shade700,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isMenuOpen ? Icons.close : Icons.menu,
              color: Colors.black,
              size: 30,
            ),
          ),
        ),
        title: Text(
          _isHomeLocationMode
              ? 'Set Home Location'
              : 'EV Charging Station Finder',
        ),
        centerTitle: true,
        backgroundColor:
            _isHomeLocationMode
                ? Colors.orange.shade600
                : Colors.greenAccent.shade700,
        actions: [
          if (!_isHomeLocationMode &&
              (searchMarkers.isNotEmpty || polylines.isNotEmpty))
            IconButton(
              icon: Icon(Icons.clear_all, color: Colors.black),
              onPressed: () {
                setState(() {
                  searchMarkers.clear();
                  polylines.clear();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Cleared all markers and routes'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              tooltip: 'Clear all',
            ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          SizedBox(
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            child: GoogleMap(
              style: _themeformap,
              mapType: MapType.normal,
              initialCameraPosition: _kGooglePlex,
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
                mapController = controller;
                stationFinder.setMapController(controller);
              },
              onCameraMove: _onCameraMove,
              markers:
                  _isHomeLocationMode
                      ? (_homeLocationMarker != null
                          ? {_homeLocationMarker!}
                          : {})
                      : allMarkers,
              polylines: _isHomeLocationMode ? {} : polylines,
            ),
          ),
          if (_isHomeLocationMode)
            Positioned(
              top: MediaQuery.of(context).size.height / 2 - 50,
              left: MediaQuery.of(context).size.width / 2 - 15,
              child: Column(
                children: [
                  Icon(Icons.location_pin, size: 30, color: Colors.green),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'Move map to set location',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Search bar and controls (hidden in home location mode)
          if (!_isHomeLocationMode)
            Positioned(
              top: 10,
              left: 20,
              right: 20,
              child: Column(
                children: [
                  LocationSearchBar(
                    selectedValue: selectedValue,
                    dropDownItems: dropDownItems,
                    onLocationSelected: _onLocationSelected,
                    onDropdownChanged: _onDropdownChanged,
                    onSearchPressed: _onSearchPressed,
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 80,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: _socController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: 'S.O.C',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 15,
                            ),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(2),
                            TextInputFormatter.withFunction((
                              oldValue,
                              newValue,
                            ) {
                              if (newValue.text.isEmpty) return newValue;
                              final int? value = int.tryParse(newValue.text);
                              if (value == null || value > 99) {
                                return oldValue;
                              }
                              return newValue;
                            }),
                          ],
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: _handleClearButtonPressed,
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.shade700,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: _handleRouteButtonPressed,
                            child: Icon(
                              Icons.route,
                              color: Colors.black,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.shade700,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              _cameraToPosition(
                                LatLng(
                                  LocationManager.shared.currentPos?.latitude ??
                                      0.0,
                                  LocationManager
                                          .shared
                                          .currentPos
                                          ?.longitude ??
                                      0.0,
                                ),
                              );
                            },
                            child: Icon(
                              Icons.my_location,
                              color: Colors.black,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (_isHomeLocationMode)
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SizedBox(
                    width: 120,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _cancelHomeLocationMode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _confirmHomeLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent.shade700,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Confirm',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_isMenuOpen && !_isHomeLocationMode)
            GestureDetector(
              onTap: _toggleMenu,
              child: Container(
                color: Colors.black.withOpacity(0.5),
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
              ),
            ),
          if (!_isHomeLocationMode)
            AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_slideAnimation.value, 0),
                  child: SizedBox(
                    width: 250,
                    height: MediaQuery.of(context).size.height,
                    child: SideMenu(
                      onHomeLocationTap: _activateHomeLocationMode,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _loadSavedHomeLocation() async {
    try {
      final homeLocationData = await HomeLocationService.getHomeLocation();
      if (homeLocationData != null) {
        final User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          userHomeStation = Station.fromFirebaseData(
            homeLocationData,
            currentUser.uid,
          );

          if (_isFullyInitialized) {
            _initializeAllStationMarkers();
          }

          setState(() {});
        }
      } else {
        userHomeStation = null;
      }
    } catch (e) {
      userHomeStation = null;
    }
  }

  void _toggleMenu() {
    if (_isHomeLocationMode) return;
    setState(() {
      _isMenuOpen = !_isMenuOpen;
    });
    if (_isMenuOpen) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  void _activateHomeLocationMode() {
    setState(() {
      _isHomeLocationMode = true;
      _isMenuOpen = false;

      _homeLocationPin =
          userHomeStation?.locationCoords ??
          LatLng(
            LocationManager.shared.currentPos?.latitude ?? 30.0076964,
            LocationManager.shared.currentPos?.longitude ?? 31.2428155,
          );

      _homeLocationMarker = Marker(
        markerId: const MarkerId('home_location_pin'),
        position: _homeLocationPin!,
        icon: iconHome!,
        draggable: false,
      );
    });

    _animationController.reverse();
    _cameraToPosition(_homeLocationPin!);
  }

  void _cancelHomeLocationMode() {
    setState(() {
      _isHomeLocationMode = false;
      _homeLocationPin = null;
      _homeLocationMarker = null;
    });
  }

  Future<void> _confirmHomeLocation() async {
    if (_homeLocationPin == null) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      Map<String, String>? addressInfo =
          await GeocodingService.getAddressFromCoordinates(_homeLocationPin!);

      addressInfo ??= GeocodingService.getSimpleAddressInfo(_homeLocationPin!);

      bool success = await HomeLocationService.saveHomeLocation(
        coordinates: _homeLocationPin!,
        streetName: addressInfo['streetName']!,
        formattedAddress: addressInfo['formattedAddress']!,
      );

      Navigator.of(context).pop();

      if (success) {
        final User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          userHomeStation = Station.homeLocation(
            address: addressInfo['streetName']!,
            formattedAddress: addressInfo['formattedAddress']!,
            locationCoords: _homeLocationPin!,
            userId: currentUser.uid,
          );
        }

        setState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Home location saved successfully!'),
            backgroundColor: Colors.greenAccent.shade700,
            duration: Duration(seconds: 3),
          ),
        );

        _cancelHomeLocationMode();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save home location. Please try again.'),
            backgroundColor: Colors.red.shade600,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving home location: $e'),
          backgroundColor: Colors.red.shade600,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _onCameraMove(CameraPosition position) {
    if (_isHomeLocationMode) {
      setState(() {
        _homeLocationPin = position.target;
        _homeLocationMarker = Marker(
          markerId: const MarkerId('home_location_pin'),
          position: _homeLocationPin!,
          icon: iconHome!,
          draggable: false,
        );
      });
    }
  }

  String _themeformap = '';
  Set<Marker> searchMarkers = {};

  String selectedValue = "20KW";
  final List<String> dropDownItems = [
    "20KW",
    "40KW",
    "70KW",
    "100KW",
    "140KW",
    "180KW",
    "220KW",
    "260KW",
    "300KW",
  ];

  Widget createStyledDropdown() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      width: 120,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8),
          bottomLeft: Radius.circular(8),
        ),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          hint: Text('Nearest battery capacity'),
          isExpanded: true,
          onChanged: (String? newValue) {
            setState(() {
              selectedValue = newValue!;
            });
          },
          items:
              dropDownItems.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value, style: TextStyle(color: Colors.black)),
                );
              }).toList(),
        ),
      ),
    );
  }

  void processSelectedValue() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("You selected $selectedValue")));
  }

  void setMarkers() {
    // Only refresh markers if they're already initialized
    if (_isFullyInitialized && iconsLoaded && iconStation != null) {
      _initializeAllStationMarkers();
    }
  }

  void addTestPolyline() {
    setState(() {
      polylines.add(
        Polyline(
          polylineId: PolylineId('test_polyline'),
          points: [LatLng(30.0444, 31.2357), LatLng(30.0626, 31.2497)],
          color: Colors.purple,
          width: 5,
        ),
      );
    });
  }

  void _onLocationSelected(LatLng location, String locationName) async {
    final searchMarker = Marker(
      markerId: MarkerId('search_result'),
      position: location,
      infoWindow: InfoWindow(title: 'Searched Location', snippet: locationName),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    );

    setState(() {
      searchMarkers.clear();
      searchMarkers.add(searchMarker);
    });

    final GoogleMapController controller = await _controller.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: location, zoom: 14),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Location found: $locationName'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.greenAccent.shade700,
      ),
    );
  }

  void _onDropdownChanged(String newValue) {
    setState(() {
      selectedValue = newValue;
    });
  }

  void _onSearchPressed() {
    processSelectedValue();
  }

  void handleFindNearestStation() async {
    try {
      if (mounted) {
        setState(() {});
      }
      await stationFinder.findNearestStationAndCreatePolyline();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // Handle error silently or with user-friendly message
    }
  }

  Future<void> _cameraToPosition(LatLng pos) async {
    try {
      final GoogleMapController controller = await _controller.future;
      CameraPosition newCameraPosition = CameraPosition(target: pos, zoom: 14);

      await controller.animateCamera(
        CameraUpdate.newCameraPosition(newCameraPosition),
      );

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error moving camera: $e');
    }
  }

  void moveCamera() async {
    final GoogleMapController controller = await _controller.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: evStations[_pageController.page!.toInt()].locationCoords,
          zoom: 14,
        ),
      ),
    );
  }

  void getIcon() async {
    try {
      var iconCarTemp = await BitmapDescriptor.asset(
        const ImageConfiguration(devicePixelRatio: 3.2),
        "assets/mapicons/car.png",
        width: 40,
        height: 40,
      );
      var iconStationTemp = await BitmapDescriptor.asset(
        const ImageConfiguration(devicePixelRatio: 3.2),
        "assets/mapicons/charging-station.png",
        width: 40,
        height: 40,
      );
      var iconHomeTemp = await BitmapDescriptor.asset(
        const ImageConfiguration(devicePixelRatio: 3.2),
        "assets/mapicons/real-estate.png",
        width: 40,
        height: 50,
      );

      if (mounted) {
        setState(() {
          iconCar = iconCarTemp;
          iconStation = iconStationTemp;
          iconHome = iconHomeTemp;
          iconsLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading icons: $e');
    }
  }

  void apiCarJoin() {
    if (!SocketManager.shared.isConnected) {
      Future.delayed(Duration(seconds: 5), () {
        if (mounted) apiCarJoin();
      });
      return;
    }

    if (ServiceCall.userUUID.isEmpty) return;

    final currentPos = LocationManager.shared.currentPos;
    if (currentPos == null) {
      Future.delayed(Duration(seconds: 3), () {
        if (mounted) apiCarJoin();
      });
      return;
    }

    currentPosition = LatLng(currentPos.latitude, currentPos.longitude);

    final requestData = {
      "uuid": ServiceCall.userUUID,
      "lat": currentPosition.latitude.toString(),
      "long": currentPosition.longitude.toString(),
      "degree": LocationManager.shared.carDegree.toString(),
      "socket_id": SocketManager.shared.socket?.id ?? "",
    };

    ServiceCall.post(
      requestData,
      SVKey.svCarJoin,
      (responseObj) async {
        if (responseObj[KKey.status] == "1") {
          final carsData = responseObj[KKey.payload] as Map? ?? {};

          carsData.forEach((key, value) {
            if (value is Map) {
              final carData = Map<String, dynamic>.from(value);
              if (!carData.containsKey("uuid")) {
                carData['uuid'] = key.toString();
              }
              updateOtherCarLocation(carData);
            }
          });

          updateMyCarLocation();

          if (mounted) {
            setState(() {});
          }

          _lastCarJoinTime = DateTime.now().millisecondsSinceEpoch;
        }
      },
      (error) async {
        Future.delayed(Duration(seconds: 5), () {
          if (mounted && SocketManager.shared.isConnected) {
            apiCarJoin();
          }
        });
      },
    );
  }

  void _startConnectionMonitoring() {
    Timer.periodic(Duration(seconds: 45), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      SocketManager.shared.testSocket();

      if (SocketManager.shared.isConnected &&
          iconsLoaded &&
          ServiceCall.userUUID.isNotEmpty) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final lastJoin = _lastCarJoinTime ?? 0;

        if (now - lastJoin > 120000) {
          apiCarJoin();
          _lastCarJoinTime = now;
        }
      }
    });
  }

  bool _storeSOCValue() {
    final String socText = _socController.text.trim();
    if (socText.isNotEmpty) {
      final int? socValue = int.tryParse(socText);
      if (socValue != null && socValue >= 0 && socValue <= 99) {
        setState(() {
          storedSOC = socValue;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('State of Charge stored: $socValue%'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.greenAccent.shade700,
          ),
        );

        _socController.clear();
        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please enter a valid number between 0-99'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red.shade600,
          ),
        );
        return false;
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a State of Charge value'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.orange.shade600,
        ),
      );
      return false;
    }
  }

  double calculateRangeInKm(int socPercentage, String batteryCapacity) {
    int capacityKw = int.parse(batteryCapacity.replaceAll('KW', ''));
    double efficiencyKmPerKwh = 4.5;
    double usableCapacity = (capacityKw * socPercentage) / 100.0;
    double rangeKm = usableCapacity * efficiencyKmPerKwh;
    return rangeKm;
  }

  double calculateRemainingBattery(
    double distanceKm,
    int initialSoc,
    String batteryCapacity,
  ) {
    int capacityKw = int.parse(batteryCapacity.replaceAll('KW', ''));
    double efficiencyKmPerKwh = 4.5;
    double energyNeeded = distanceKm / efficiencyKmPerKwh;
    double totalEnergy = capacityKw.toDouble();
    double currentEnergy = (totalEnergy * initialSoc) / 100.0;
    double remainingEnergy = currentEnergy - energyNeeded;
    double remainingPercentage = (remainingEnergy / totalEnergy) * 100.0;
    return remainingPercentage.clamp(0.0, 100.0);
  }

  Future<void> _showBatteryWarningDialog(
    LatLng destination,
    String locationName,
    double estimatedRemainingBattery,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.battery_alert, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text('Battery Warning'),
            ],
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'Based on your current battery level (${storedSOC ?? 0}%) and selected capacity ($selectedValue), '
                  'traveling to "$locationName" will leave you with approximately ${estimatedRemainingBattery.toStringAsFixed(1)}% battery.',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    'It\'s recommended to make a detour to the nearest charging station before going to your destination.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Deny',
                style: TextStyle(color: Colors.red.shade600, fontSize: 16),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _createRouteToDestination(destination, locationName);
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent.shade700,
                foregroundColor: Colors.black,
              ),
              child: Text('Agree', style: TextStyle(fontSize: 16)),
              onPressed: () {
                Navigator.of(context).pop();
                _createRouteToNearestStation();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _createRouteToDestination(
    LatLng destination,
    String locationName,
  ) async {
    try {
      LatLng currentLocation = LatLng(
        LocationManager.shared.currentPos?.latitude ?? 0.0,
        LocationManager.shared.currentPos?.longitude ?? 0.0,
      );

      if (currentLocation.latitude == 0.0 && currentLocation.longitude == 0.0) {
        showSnackBar('Current location not available', Colors.red.shade600);
        return;
      }

      Directions? directions = await stationFinder.getDirections(
        origin: currentLocation,
        destination: destination,
      );

      if (directions != null) {
        List<LatLng> polylineCoordinates =
            directions.polylinePoints
                .map((point) => LatLng(point.latitude, point.longitude))
                .toList();

        Polyline routePolyline = Polyline(
          polylineId: const PolylineId('route_to_destination'),
          points: polylineCoordinates,
          color: Colors.purple,
          width: 5,
          geodesic: true,
        );

        setState(() {
          polylines.clear();
          polylines.add(routePolyline);
        });

        await _fitCameraToPolyline(routePolyline);
        showSnackBar('Route created to $locationName', Colors.blue.shade600);
      } else {
        showSnackBar(
          'Could not create route to destination',
          Colors.red.shade600,
        );
      }
    } catch (e) {
      showSnackBar('Error creating route: $e', Colors.red.shade600);
    }
  }

  Future<void> _createRouteToNearestStation() async {
    await stationFinder.findNearestLocationAndCreatePolyline();

    await Future.delayed(Duration(milliseconds: 500));
    if (polylines.isNotEmpty) {
      await _fitCameraToPolyline(polylines.first);
    }

    Station? nearestLocation = stationFinder.findNearestAnyLocation(
      LatLng(
        LocationManager.shared.currentPos?.latitude ?? 0.0,
        LocationManager.shared.currentPos?.longitude ?? 0.0,
      ),
    );

    String locationTypeMessage = "nearest location";
    Color snackBarColor = Colors.green.shade600;

    if (nearestLocation != null) {
      if (nearestLocation.isHomeLocation) {
        locationTypeMessage = "home location";
        snackBarColor = Colors.blue.shade600;
      } else {
        locationTypeMessage = "nearest charging station";
        snackBarColor = Colors.green.shade600;
      }
    }

    showSnackBar('Route created to $locationTypeMessage', snackBarColor);
  }

  void showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 3),
        backgroundColor: backgroundColor,
      ),
    );
  }

  Future<void> _fitCameraToPolyline(Polyline polyline) async {
    if (polyline.points.isEmpty) return;

    try {
      final GoogleMapController controller = await _controller.future;

      double minLat = polyline.points.first.latitude;
      double maxLat = polyline.points.first.latitude;
      double minLng = polyline.points.first.longitude;
      double maxLng = polyline.points.first.longitude;

      for (LatLng point in polyline.points) {
        minLat = math.min(minLat, point.latitude);
        maxLat = math.max(maxLat, point.latitude);
        minLng = math.min(minLng, point.longitude);
        maxLng = math.max(maxLng, point.longitude);
      }

      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );

      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100.0),
      );
    } catch (e) {
      try {
        final GoogleMapController controller = await _controller.future;
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: polyline.points.first, zoom: 12),
          ),
        );
      } catch (fallbackError) {
        debugPrint('Fallback camera move also failed: $fallbackError');
      }
    }
  }

  Future<void> _handleRouteButtonPressed() async {
    _storeSOCValue();

    if (storedSOC == null) {
      showSnackBar(
        'Please enter State of Charge first',
        Colors.orange.shade600,
      );
      return;
    }

    if (searchMarkers.isEmpty) {
      await stationFinder.findNearestStationAndCreatePolyline();
      return;
    }

    Marker searchMarker = searchMarkers.first;
    LatLng destination = searchMarker.position;
    String locationName =
        searchMarker.infoWindow.snippet ?? 'Selected Location';

    LatLng currentLocation = LatLng(
      LocationManager.shared.currentPos?.latitude ?? 0.0,
      LocationManager.shared.currentPos?.longitude ?? 0.0,
    );

    if (currentLocation.latitude == 0.0 && currentLocation.longitude == 0.0) {
      showSnackBar('Current location not available', Colors.red.shade600);
      return;
    }

    double distanceToDestination = stationFinder.calculateDistance(
      currentLocation,
      destination,
    );

    double remainingBattery = calculateRemainingBattery(
      distanceToDestination,
      storedSOC!,
      selectedValue,
    );

    if (remainingBattery < 20.0) {
      await _showBatteryWarningDialog(
        destination,
        locationName,
        remainingBattery,
      );
    } else {
      await _createRouteToDestination(destination, locationName);
    }
  }

  void _handleClearButtonPressed() {
    setState(() {
      polylines.clear();
    });
    showSnackBar('All routes cleared', Colors.grey.shade600);
  }
}
