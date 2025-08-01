import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

typedef ResSuccess = Future<void> Function(Map<String, dynamic>);
typedef ResFailure = Future<void> Function(dynamic);

class ServiceCall {
  static String userUUID = "";
  static String baseUrl = ""; // Add your Google Cloud server URL here

  static void post(
      Map<String, dynamic> parameter,
      String path,
      ResSuccess? withSuccess,
      ResFailure? failure,
      ) {
    Future(() {
      try {
        var headers = {
          "Content-Type": 'application/x-www-form-urlencoded',
          "User-Agent": "Flutter-App/1.0",
        };

        // Log the request details
        if (kDebugMode) {
          print("=== HTTP REQUEST ===");
          print("URL: $path");
          print("Parameters: $parameter");
          print("Headers: $headers");
        }

        final startTime = DateTime.now();

        http
            .post(Uri.parse(path), body: parameter, headers: headers)
            .timeout(const Duration(seconds: 30))
            .then((value) {
          final endTime = DateTime.now();
          final duration = endTime.difference(startTime);

          if (kDebugMode) {
            print("=== HTTP RESPONSE ===");
            print("URL: $path");
            print("Status Code: ${value.statusCode}");
            print("Response Time: ${duration.inMilliseconds}ms");
            print("Response Body: ${value.body}");
            print("===================");
          }

          if (value.statusCode != 200) {
            if (failure != null) {
              failure("HTTP ${value.statusCode}: ${value.reasonPhrase}");
            }
            return;
          }

          try {
            var jsonObj = json.decode(value.body) as Map<String, dynamic>? ?? {};

            // Additional logging for car-related endpoints
            if (path.contains('car') || path.contains('location')) {
              if (kDebugMode) {
                print("Car location response: $jsonObj");
              }
            }

            if (withSuccess != null) withSuccess(jsonObj);
          } catch (e) {
            if (kDebugMode) {
              print("JSON parsing error for $path: $e");
              print("Raw response: ${value.body}");
            }
            if (failure != null) failure(e);
          }
        })
            .catchError((e) {
          final endTime = DateTime.now();
          final duration = endTime.difference(startTime);

          if (kDebugMode) {
            print("=== HTTP ERROR ===");
            print("URL: $path");
            print("Error after ${duration.inMilliseconds}ms: $e");
            print("==================");
          }
          if (failure != null) failure(e);
        });
      } catch (e) {
        if (kDebugMode) {
          print("Service call setup error: $e");
        }
        if (failure != null) failure(e);
      }
    });
  }

  // Add a method to test connectivity
  static Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/health"), // Add a health check endpoint
        headers: {"Content-Type": "application/json"},
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print("Connection test failed: $e");
      }
      return false;
    }
  }
}