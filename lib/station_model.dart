import 'package:google_maps_flutter/google_maps_flutter.dart';

enum StationType {
  chargingStation,
  homeLocation,
}

class Station {
  String stationName;
  String address;
  String thumbNail;
  LatLng locationCoords;
  StationType type; // Remove the ? to make it non-nullable
  String? userId; // For home locations, to identify which user it belongs to

  Station({
    required this.stationName,
    required this.address,
    required this.thumbNail,
    required this.locationCoords,
    this.type = StationType.chargingStation, // Default value ensures it's never null
    this.userId,
  });

  // Factory constructor to create a home location station
  factory Station.homeLocation({
    required String address,
    required String formattedAddress,
    required LatLng locationCoords,
    required String userId,
  }) {
    return Station(
      stationName: 'Home Location',
      address: address,
      thumbNail: 'assets/mapicons/home.png',
      locationCoords: locationCoords,
      type: StationType.homeLocation, // Explicitly set the type
      userId: userId,
    );
  }

  // Helper method to check if this is a home location
  bool get isHomeLocation => type == StationType.homeLocation;

  // Helper method to check if this is a charging station
  bool get isChargingStation => type == StationType.chargingStation;

  // Convert from Firebase data
  factory Station.fromFirebaseData(Map<String, dynamic> data, String userId) {
    return Station.homeLocation(
      address: data['streetName'] ?? 'Home Location',
      formattedAddress: data['formattedAddress'] ?? '',
      locationCoords: LatLng(
        data['latitude'] ?? 0.0,
        data['longitude'] ?? 0.0,
      ),
      userId: userId,
    );
  }

  // Convert to Firebase data
  Map<String, dynamic> toFirebaseData() {
    return {
      'stationName': stationName,
      'address': address,
      'latitude': locationCoords.latitude,
      'longitude': locationCoords.longitude,
      'type': type.name,
      'userId': userId,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }
}

List<Station> initializeEvStations() {
  return [
    Station(
      stationName: 'Virta Charging Station',
      address: 'First 6th of October, Giza Governorate 3234301',
      thumbNail: 'assets/mapicons/Virta.png',
      locationCoords: LatLng(29.967578, 30.968334),
    ),
    Station(
      stationName: 'Infinity-e Charging Station',
      address: 'Waslet Dahshur Rd, First 6th of October, Giza Governorate 12311',
      thumbNail: 'assets/mapicons/Infinitye.png',
      locationCoords: LatLng(30.015623, 30.975284),
    ),
    Station(
      stationName: 'Revolta Charging Station',
      address: 'Sheik Zayed City, شارع البستان',
      thumbNail: 'assets/mapicons/Revolta.png',
      locationCoords: LatLng(30.020773, 31.003364),
    ),
    Station(
      stationName: 'Revolta Charging Station',
      address: '97 Nile Corniche, Tag Ad Dewal, Imbaba, Giza Governorate 12344',
      thumbNail: 'assets/mapicons/Revolta.png',
      locationCoords: LatLng(30.076113, 31.209138),
    ),
    Station(
      stationName: 'Revolta Charging Station',
      address: '329H+9G9, KM 28, Kerdasa, Giza Governorate 3650306',
      thumbNail: 'assets/mapicons/Revolta.png',
      locationCoords: LatLng(30.068360, 31.028829),
    ),
    Station(
      stationName: 'Revolta Charging Station',
      address:
      '2273+MG4, Unnamed Road, First 6th of October, Giza Governorate 3292302',
      thumbNail: 'assets/mapicons/Revolta.png',
      locationCoords: LatLng(30.014112, 31.003810),
    ),
    Station(
      stationName: 'Revolta Charging Station',
      address:
      '40 26th of July Corridor, First Al Sheikh Zayed, Giza Governorate 3242302',
      thumbNail: 'assets/mapicons/Revolta.png',
      locationCoords: LatLng(30.016704, 31.001304),
    ),
    Station(
      stationName: 'Revolta Charging Station',
      address:
      'Kobri Al Ebageah, Al Abageyah, El Khalifa, Cairo Governorate 4253070',
      thumbNail: 'assets/mapicons/Revolta.png',
      locationCoords: LatLng(30.028399, 31.266728),
    ),
    Station(
      stationName: 'Revolta Charging Station',
      address:
      'Cairo - Sweis Road, Ezbet Fahmy, El Basatin, Cairo Governorate 4235001',
      thumbNail: 'assets/mapicons/Revolta.png',
      locationCoords: LatLng(29.967496, 31.312104),
    ),
    Station(
      stationName: 'Revolta Charging Station',
      address: 'El Basatin, Cairo Governorate 4237026',
      thumbNail: 'assets/mapicons/Revolta.png',
      locationCoords: LatLng(29.977281, 31.358263),
    ),
    Station(
      stationName: 'Revolta Charging Station',
      address: 'Unnamed Road, New Cairo 1, Cairo Governorate 4730020',
      thumbNail: 'assets/mapicons/Revolta.png',
      locationCoords: LatLng(30.0298073, 31.4066663),
    ),
    Station(
      stationName: 'Revolta Charging Station',
      address: 'Suez Rd, Second New Cairo, Cairo Governorate 4736021',
      thumbNail: 'assets/mapicons/Revolta.png',
      locationCoords: LatLng(30.079970, 31.454536),
    ),
    Station(
      stationName: 'Revolta Charging Station',
      address:
      '3F4R+C9Q, Abou Hanifa Al Noaman, Second New Cairo, Cairo Governorate 4750131',
      thumbNail: 'assets/mapicons/Revolta.png',
      locationCoords: LatLng(30.056085, 31.490980),
    ),
    Station(
      stationName: 'BMW Destination Charging Station',
      address: '3C69+98M, Ring Rd, Second New Cairo, Cairo Governorate 4732021',
      thumbNail: 'assets/mapicons/BMW.png',
      locationCoords: LatLng(30.060937, 31.418281),
    ),
    Station(
      stationName: 'Infinity Charging Station',
      address: 'Golf, Palm Hills, First 6th of October, Giza Governorate 12311',
      thumbNail: 'assets/mapicons/Infinitye.png',
      locationCoords: LatLng(30.008271, 31.034015),
    ),
    Station(
      stationName: 'Infinity EV Station',
      address:
      'Gezira Sporting Club, near, First 6th of October, الجيزة, Giza Governorate 12311',
      thumbNail: 'assets/mapicons/Infinitye.png',
      locationCoords: LatLng(30.001964, 31.032769),
    ),
    Station(
      stationName: 'Infinity Charging Station',
      address: 'New giza clup 6th of October City, Giza Governorate 12311',
      thumbNail: 'assets/mapicons/Infinitye.png',
      locationCoords: LatLng(30.004708, 31.066268),
    ),
    Station(
      stationName: 'Infinity Charging Station',
      address: 'New giza , near newgiza golf cloub house 6th of October City',
      thumbNail: 'assets/mapicons/Infinitye.png',
      locationCoords: LatLng(30.007636, 31.055828),
    ),
    Station(
      stationName: 'Sha7en EV Solutions',
      address: '10 Omar Ibn El-Khattab, Ad Doqi, Dokki, Giza Governorate 12311',
      thumbNail: 'assets/mapicons/Sha7en.png',
      locationCoords: LatLng(30.041060, 31.197336),
    ),
    Station(
      stationName: 'Sha7en Charging Station',
      address: '2X2P+FRG, First 6th of October, Giza Governorate 3238059',
      thumbNail: 'assets/mapicons/Sha7en.png',
      locationCoords: LatLng(30.041060, 31.197336),
    ),
    Station(
      stationName: 'Sha7en Charging Station',
      address: '2X8F+XC7, Second Al Sheikh Zayed, Giza Governorate 3236167',
      thumbNail: 'assets/mapicons/Sha7en.png',
      locationCoords: LatLng(30.017777, 30.973656),
    ),
    Station(
      stationName: 'Sha7en Charging Station',
      address: '2CXR+RHP, Second New Cairo, Cairo Governorate 4731501',
      thumbNail: 'assets/mapicons/Sha7en.png',
      locationCoords: LatLng(30.049500, 31.441590),
    ),
    Station(
      stationName: 'Sha7en Charging Station',
      address:
      'Building A5 ICON, South 90th st, 5th Settlement, Cairo Governorate 11835',
      thumbNail: 'assets/mapicons/Sha7en.png',
      locationCoords: LatLng(30.025842, 31.495265),
    ),
    Station(
      stationName: 'Sha7en-City Walk Station',
      address:
      '2WXX+3GH, Waslet Dahshur Rd, Second Al Sheikh Zayed, Giza Governorate 3240302',
      thumbNail: 'assets/mapicons/Sha7en.png',
      locationCoords: LatLng(30.047684, 30.948867),
    ),
    Station(
      stationName: 'Revolta Charging Station',
      address:
      'Kobri Al Ebageah, Al Abageyah, El Khalifa, Cairo Governorate 4253070',
      thumbNail: 'assets/mapicons/Revolta.png',
      locationCoords: LatLng(30.028414, 31.266765),
    ),
    Station(
      stationName: 'Infinity Charging Station',
      address:
      'Emtedad Ramses, As Sarayat Ash Sharqeyah, Nasr City, Cairo Governorate 12311',
      thumbNail: 'assets/mapicons/Infinitye.png',
      locationCoords: LatLng(30.065442, 31.295249),
    ),
    Station(
      stationName: 'Infinity Charging Station',
      address: 'Al Estad, Qesm Than Madinet Nasr, Cairo Governorate 12311',
      thumbNail: 'assets/mapicons/Infinitye.png',
      locationCoords: LatLng(30.076970, 31.311671),
    ),
    Station(
      stationName: 'AI Car',
      address:
      '38G6+RQV, Al Estad, Qesm Than Madinet Nasr, Cairo Governorate 4436021',
      thumbNail: 'assets/mapicons/charging-station.png',
      locationCoords: LatLng(30.077121, 31.311910),
    ),
    Station(
      stationName: 'Infinity Charging Station',
      address:
      'محطة شيل اوت-طريق المسجد المشير االمتجه الي، كوبرى 6 أكتوبر، 12311',
      thumbNail: 'assets/mapicons/Infinitye.png',
      locationCoords: LatLng(30.021396, 31.328948),
    ),
    Station(
      stationName: 'Infinity Charging Station',
      address: 'Madinat Al-Amal, Nasr City, Cairo Governorate 12311',
      thumbNail: 'assets/mapicons/Infinitye.png',
      locationCoords: LatLng(30.080039, 31.397410),
    ),
    Station(
      stationName: 'Infinity Charging Station',
      address:
      'طريق القطامية العين السخنة, El Katameya، القاهرة, Cairo Governorate 4064070',
      thumbNail: 'assets/mapicons/Infinitye.png',
      locationCoords: LatLng(29.960895, 31.455255),
    ),
    Station(
      stationName: 'Infinity-e Charging Station',
      address: 'toll road, New Cairo 3, Cairo Governorate 12311',
      thumbNail: 'assets/mapicons/Infinitye.png',
      locationCoords: LatLng(29.960021, 31.451937),
    ),
    Station(
      stationName: 'Plug Charging Station',
      address: 'New Cairo 1, Cairo Governorate 4725450',
      thumbNail: 'assets/mapicons/charging-station.png',
      locationCoords: LatLng(30.025113, 31.482688),
    ),
    Station(
      stationName: 'Ikarus Charging Station',
      address: 'Trivium Square 5th Settlement, Cairo Governorate 11835',
      thumbNail: 'assets/mapicons/Ikarus.png',
      locationCoords: LatLng(30.027909, 31.477849),
    ),
    Station(
      stationName: 'Ikarus Charging Station',
      address: '3F59+26G, New Cairo 1, Cairo Governorate 4735420',
      thumbNail: 'assets/mapicons/Ikarus.png',
      locationCoords: LatLng(30.057230, 31.467587),
    ),
    Station(
      stationName: 'Ikarus Charging Station',
      address: '142 Street 53, New Cairo 1, Cairo Governorate 11835',
      thumbNail: 'assets/mapicons/Ikarus.png',
      locationCoords: LatLng(30.010331, 31.436171),
    ),
    Station(
      stationName: 'Ikarus Charging Station',
      address:
      'XCRM+C3W, Gamal Abdel Nasser, Street, New Cairo 1, Cairo Governorate 11835',
      thumbNail: 'assets/mapicons/Ikarus.png',
      locationCoords: LatLng(29.991088, 31.432732),
    ),
    Station(
      stationName: 'Ikarus Charging Station',
      address:
      'طريق مصر, Ismailia Desert Rd, Ismailia Governorate, Cairo Governorate 11828',
      thumbNail: 'assets/mapicons/Ikarus.png',
      locationCoords: LatLng(30.160523, 31.462725),
    ),
    Station(
      stationName: 'Ikarus Charging Station',
      address:
      'B Square- C Building, El-Nasr Rd, Al Manteqah Al Oula, Nasr City, Cairo Governorate 11765',
      thumbNail: 'assets/mapicons/Ikarus.png',
      locationCoords: LatLng(30.068029, 31.332820),
    ),
    Station(
      stationName: 'Ikarus Charging Station',
      address:
      'داخل سويل لايك مول, Waslet Dahshur Rd, First 6th of October, Giza Governorate 3238231',
      thumbNail: 'assets/mapicons/Ikarus.png',
      locationCoords: LatLng(29.990019, 30.997335),
    ),
    Station(
      stationName: 'Ikarus Charging Station',
      address:
      'Rally Group Luxury Branch, Gasoline Street, 6th of October City (2), Giza Governorate 12411',
      thumbNail: 'assets/mapicons/Ikarus.png',
      locationCoords: LatLng(29.919200, 30.915527),
    ),
    Station(
      stationName: 'Infinity Charging Station',
      address: 'Al Sadat Axis, New Cairo 1, Cairo Governorate 4735320',
      thumbNail: 'assets/mapicons/Infinitye.png',
      locationCoords: LatLng(30.053394, 31.468559),
    ),
    Station(
      stationName: 'Infinity Charging Station',
      address:
      '11835, Dusit Thani Hotel شارع التسعين الجنوبي The Club, New Cairo 1, Cairo Governorate 12311',
      thumbNail: 'assets/mapicons/Infinitye.png',
      locationCoords: LatLng(30.025487, 31.455528),
    ),
    Station(
      stationName: 'Infinity Charging Station',
      address: 'Madinaty, Second New Cairo, Cairo Governorate 12311',
      thumbNail: 'assets/mapicons/Infinitye.png',
      locationCoords: LatLng(30.103868, 31.601328),
    ),
    Station(
      stationName: 'Infinity Charging Station',
      address: '4FH7+VHH, El Nozha, Cairo Governorate 4475001',
      thumbNail: 'assets/mapicons/Infinitye.png',
      locationCoords: LatLng(30.129688, 31.463984),
    ),
    Station(
      stationName: 'Porsche Destination Charging',
      address: '11835 S Teseen, New Cairo 1, Cairo Governorate 4730203',
      thumbNail: 'assets/mapicons/Porsche.png',
      locationCoords: LatLng(30.024530, 31.454544),
    ),
    Station(
      stationName: 'Revolta Charging Station',
      address: 'El Shorouk, Cairo Governorate 4920212',
      thumbNail: 'assets/mapicons/Revolta.png',
      locationCoords: LatLng(30.118285, 31.610668),
    ),
  ];
}
final List<Station> evStations = initializeEvStations();

void ensureStationTypesAreSet() {
  for (int i = 0; i < evStations.length; i++) {
    Station _ = evStations[i];
  }
}

Station? userHomeStation;