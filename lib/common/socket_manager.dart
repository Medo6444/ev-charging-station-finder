import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:grad02/common/service_call.dart';
import 'package:grad02/common/glob.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketManager {
  static final SocketManager sigleton = SocketManager._internal();
  SocketManager._internal();
  IO.Socket? socket;
  bool _isConnected = false;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _retryCount = 0;
  final int _maxRetries = 10;
  bool _isManualDisconnect = false;

  static SocketManager get shared => sigleton;

  void initSocket() {
    // Clean up existing socket if any
    if (socket != null) {
      _cleanupSocket();
    }

    String socketUrl = SVKey.nodeURL.trim();

    // Fix URL formatting for Google Cloud deployment
    if (socketUrl.contains(':0')) {
      socketUrl = socketUrl.replaceAll(':0', '');
    }

    // Remove any trailing slashes
    socketUrl = socketUrl.replaceAll(RegExp(r'/+$'), '');

    // Ensure HTTPS for Google Cloud
    if (!socketUrl.startsWith('http://') && !socketUrl.startsWith('https://')) {
      socketUrl = 'https://$socketUrl';
    }

    // For Google Cloud, force HTTPS if it's using HTTP
    if (socketUrl.startsWith('http://') && !socketUrl.contains('localhost')) {
      socketUrl = socketUrl.replaceFirst('http://', 'https://');
    }

    if (kDebugMode) {
      print("=== SOCKET INITIALIZATION ===");
      print("Original URL: ${SVKey.nodeURL}");
      print("Processed URL: $socketUrl");
      print("User UUID: ${ServiceCall.userUUID}");
      print("=============================");
    }

    socket = IO.io(socketUrl,
        IO.OptionBuilder()
            .setTransports(['polling', 'websocket']) // Start with polling for cloud
            .enableAutoConnect()
            .setTimeout(60000) // Increased timeout for cloud
            .enableForceNew()
            .setReconnectionAttempts(_maxRetries)
            .setReconnectionDelay(3000) // Increased delay
            .setReconnectionDelayMax(15000) // Increased max delay
            .setQuery({'transport': 'polling'}) // Force polling initially
            .setExtraHeaders({
          'Accept': '*/*',
          'User-Agent': 'Flutter-App/1.0',
          'Origin': socketUrl, // Add origin header
        })
            .build()
    );

    _setupSocketListeners();
    _startHeartbeat();
  }

  void _setupSocketListeners() {
    socket?.on("connect", (data) {
      _isConnected = true;
      _retryCount = 0;
      _isManualDisconnect = false;

      if (kDebugMode) {
        print("✅ Socket Connected Successfully!");
        print("Socket ID: ${socket?.id}");
        print("Transport: ${socket?.io.engine?.transport?.name}");
        print("URL: ${SVKey.nodeURL}");
        print("Timestamp: ${DateTime.now().toIso8601String()}");
      }

      updateSocketIdApi();
    });

    socket?.on("connect_error", (data) {
      _isConnected = false;
      if (kDebugMode) {
        print("❌ Socket Connect Error:");
        print("Error: $data");
        print("URL: ${SVKey.nodeURL}");
        print("Retry count: $_retryCount/$_maxRetries");
      }

      if (!_isManualDisconnect) {
        _scheduleReconnect();
      }
    });

    socket?.on("error", (data) {
      if (kDebugMode) {
        print("❌ Socket Error: $data");
      }
    });

    socket?.on("disconnect", (reason) {
      _isConnected = false;
      if (kDebugMode) {
        print("🔌 Socket Disconnected: $reason");
        print("Was manual disconnect: $_isManualDisconnect");
      }

      // Auto-reconnect unless it was a manual disconnect
      if (!_isManualDisconnect && reason != "io client disconnect") {
        _scheduleReconnect();
      }
    });

    socket?.on("reconnect", (attemptNumber) {
      _isConnected = true;
      _retryCount = 0;
      if (kDebugMode) {
        print("🔄 Socket Reconnected after $attemptNumber attempts");
        print("New Socket ID: ${socket?.id}");
      }
      updateSocketIdApi();
    });

    socket?.on("reconnect_error", (data) {
      if (kDebugMode) {
        print("❌ Socket Reconnection Error: $data");
      }
    });

    socket?.on("reconnect_failed", (data) {
      _isConnected = false;
      if (kDebugMode) {
        print("❌ Socket Reconnection Failed completely: $data");
      }
    });

    // Add ping/pong handlers for connection health
    socket?.on("ping", (data) {
      if (kDebugMode) {
        print("📡 Received ping from server");
      }
    });

    socket?.on("pong", (data) {
      if (kDebugMode) {
        print("📡 Received pong from server");
      }
    });

    // Car-specific event listeners with enhanced logging
    socket?.on(SVKey.nvCarJoin, (data) {
      if (kDebugMode) {
        print("🚗 Received nvCarJoin event:");
        print("Data: $data");
        print("Status: ${data?[KKey.status]}");
        if (data?[KKey.payload] != null) {
          print("Payload cars count: ${(data[KKey.payload] as Map).length}");
        }
      }
    });

    socket?.on(SVKey.nvCarUpdateLocation, (data) {
      if (kDebugMode) {
        print("📍 Received nvCarUpdateLocation event:");
        print("Data: $data");
        if (data?[KKey.payload] != null) {
          final payload = data[KKey.payload] as Map;
          print("Car UUID: ${payload['uuid']}");
          print("Coordinates: ${payload['lat']}, ${payload['long']}");
          print("Degree: ${payload['degree']}");
        }
      }
    });

    socket?.on("UpdateSocket", (data) {
      if (kDebugMode) {
        print("🔄 UpdateSocket event received:");
        print("Data: $data");
      }
    });
  }

  void _scheduleReconnect() {
    if (_retryCount >= _maxRetries || _isManualDisconnect) {
      if (kDebugMode) {
        print("🛑 Max retry attempts reached or manual disconnect. Stopping reconnection.");
      }
      return;
    }

    _reconnectTimer?.cancel();

    final delay = Duration(seconds: (2 << _retryCount).clamp(2, 30));
    _retryCount++;

    if (kDebugMode) {
      print("⏳ Scheduling reconnection in ${delay.inSeconds} seconds (attempt $_retryCount/$_maxRetries)");
    }

    _reconnectTimer = Timer(delay, () {
      if (!_isConnected && !_isManualDisconnect) {
        if (kDebugMode) {
          print("🔄 Attempting to reconnect...");
        }
        socket?.connect();
      }
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(Duration(seconds: 25), (timer) {
      if (_isConnected && socket != null) {
        try {
          socket?.emit('ping', {
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'uuid': ServiceCall.userUUID
          });

          if (kDebugMode) {
            print("💓 Heartbeat sent");
          }
        } catch (e) {
          if (kDebugMode) {
            print("❌ Heartbeat error: $e");
          }
        }
      }
    });
  }

  Future updateSocketIdApi() async {
    if (ServiceCall.userUUID.isEmpty || !_isConnected || socket?.id == null) {
      if (kDebugMode) {
        print("⚠️ Cannot update socket ID:");
        print("User UUID empty: ${ServiceCall.userUUID.isEmpty}");
        print("Connected: $_isConnected");
        print("Socket ID null: ${socket?.id == null}");
      }
      return;
    }

    try {
      final updateData = {
        'uuid': ServiceCall.userUUID,
        'socketId': socket?.id,
        'timestamp': DateTime.now().toIso8601String(),
        'platform': 'flutter'
      };

      socket?.emit("UpdateSocket", jsonEncode(updateData));

      if (kDebugMode) {
        print("✅ Socket ID updated successfully:");
        print("User UUID: ${ServiceCall.userUUID}");
        print("Socket ID: ${socket?.id}");
        print("Data sent: $updateData");
      }

      _retryCount = 0; // Reset retry count on successful operation
    } catch (e) {
      if (kDebugMode) {
        print("❌ Socket updateSocketIdApi error: ${e.toString()}");
      }
    }
  }

  // Enhanced connection status check
  bool get isConnected => _isConnected && socket?.connected == true && socket?.id != null;

  // Method to get detailed connection info
  Map<String, dynamic> getConnectionInfo() {
    return {
      'isConnected': isConnected,
      'socketId': socket?.id,
      'transport': socket?.io.engine?.transport?.name,
      'url': SVKey.nodeURL,
      'retryCount': _retryCount,
      'maxRetries': _maxRetries,
      'userUUID': ServiceCall.userUUID,
      'isManualDisconnect': _isManualDisconnect,
    };
  }

  // Method to manually reconnect
  void reconnect() {
    if (kDebugMode) {
      print("🔄 Manual reconnect requested");
    }

    _isManualDisconnect = false;
    _retryCount = 0;

    if (socket != null) {
      if (socket!.connected) {
        socket?.disconnect();
      }
      socket?.connect();
    } else {
      initSocket();
    }
  }

  // Clean disconnect method
  void disconnect() {
    if (kDebugMode) {
      print("🔌 Manual disconnect requested");
    }

    _isManualDisconnect = true;
    _isConnected = false;
    _cleanupSocket();
  }

  void _cleanupSocket() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    socket?.disconnect();
    socket?.dispose();
    socket = null;
  }

  // Method to check if socket is properly initialized
  bool get isInitialized => socket != null;

  // Enhanced emit method with retry logic
  void emitWithErrorHandling(String event, dynamic data, {int maxRetries = 3}) {
    _emitWithRetry(event, data, maxRetries, 0);
  }

  void _emitWithRetry(String event, dynamic data, int maxRetries, int currentAttempt) {
    try {
      if (isConnected) {
        socket?.emit(event, data);
        if (kDebugMode) {
          print("📤 Emitted $event successfully");
        }
      } else {
        if (kDebugMode) {
          print("⚠️ Cannot emit $event: Socket not connected");
          print("Connection status: ${getConnectionInfo()}");
        }

        // Retry if not at max attempts
        if (currentAttempt < maxRetries) {
          if (kDebugMode) {
            print("🔄 Retrying emit in 1 second (attempt ${currentAttempt + 1}/$maxRetries)");
          }

          Timer(Duration(seconds: 1), () {
            _emitWithRetry(event, data, maxRetries, currentAttempt + 1);
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ Error emitting $event: ${e.toString()}");
      }

      // Retry on error if not at max attempts
      if (currentAttempt < maxRetries) {
        Timer(Duration(seconds: 1), () {
          _emitWithRetry(event, data, maxRetries, currentAttempt + 1);
        });
      }
    }
  }

  // Test method to verify socket functionality
  void testSocket() {
    if (kDebugMode) {
      print("=== SOCKET TEST ===");
      print("Connection Info: ${getConnectionInfo()}");

      if (isConnected) {
        socket?.emit('test', {
          'message': 'Test from Flutter',
          'timestamp': DateTime.now().toIso8601String(),
          'uuid': ServiceCall.userUUID
        });
        print("Test message sent");
      } else {
        print("Cannot test: Socket not connected");
      }
      print("==================");
    }
  }

  // Dispose method for cleanup
  void dispose() {
    _isManualDisconnect = true;
    _cleanupSocket();
  }
}