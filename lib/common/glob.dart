import 'package:grad02/main.dart';

class Glob {
  static const appName = "Charging Station Locator";
  static void udStringSet(String data, String key) {
    prefs?.setString(key, data);
  }
  static String udValueString(String key) {
    return prefs?.getString(key) ?? "";
  }
}

class SVKey {
  // Your new cloud server URL
  static const mainURL = "https://molten-turbine-465717-c4.uc.r.appspot.com";
  static const baseURL = "$mainURL/api/";
  static const nodeURL = mainURL;
  static const nvCarJoin = "car_join";
  static const nvCarUpdateLocation = "car_update_location";
  static const svCarJoin = "$baseURL$nvCarJoin";
  static const svCarUpdateLocation = "$baseURL$nvCarUpdateLocation";
}

class KKey {
  static const payload = "payload";
  static const status = "status";
  static const message = "message";
}

class MSG {
  static const success = "success";
  static const fail = "fail";
}