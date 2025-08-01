var helper = require('./../helpers/helpers')

module.exports.controller = (app, io, socket_list) => {
    const msg_success = "successfully"
    const msg_fail = "fail"

    // Enhanced car location object with better tracking
    const car_location_obj = {}

    // Helper function to broadcast to all clients except sender
    function broadcastCarUpdate(senderSocketId, eventName, data) {
        helper.Dlog(`Broadcasting ${eventName} to all clients except ${senderSocketId}`);

        // Get all connected sockets
        const connectedSockets = io.sockets.sockets;

        connectedSockets.forEach((socket, socketId) => {
            if (socketId !== senderSocketId) {
                socket.emit(eventName, data);
                helper.Dlog(`Sent ${eventName} to socket: ${socketId}`);
            }
        });
    }

    app.post('/api/car_update_location', (req, res) => {
        helper.Dlog("=== CAR LOCATION UPDATE ===");
        helper.Dlog(req.body);

        var reqObj = req.body;
        helper.CheckParameterValid(res, reqObj, ['uuid', 'lat', 'long', 'degree'], () => {
            try {
                const socketId = reqObj.socket_id || 'http_only';

                // ADD THIS: Validate degree value
                let degree = parseFloat(reqObj.degree);
                if (isNaN(degree) || degree < 0 || degree >= 360) {
                    degree = 0.0;
                    helper.Dlog(`⚠️ Fixed invalid degree for ${reqObj.uuid}, set to 0.0`);
                }

                // Update socket list if socket_id is provided
                if (reqObj.socket_id && reqObj.socket_id !== '') {
                    socket_list['us_' + reqObj.uuid] = {
                        'socket_id': reqObj.socket_id,
                        'last_update': new Date().toISOString()
                    };
                }

                // Update car location with timestamp
                car_location_obj[reqObj.uuid] = {
                    'uuid': reqObj.uuid,
                    'lat': parseFloat(reqObj.lat),
                    'long': parseFloat(reqObj.long),
                    'degree': degree, // Use validated degree
                    'lastUpdate': Date.now(),
                    'socket_id': socketId,
                    'updated_at': new Date().toISOString()
                };

                helper.Dlog(`Updated location for UUID: ${reqObj.uuid} - Lat: ${reqObj.lat}, Long: ${reqObj.long}, Degree: ${degree}`);

                // Broadcast to all OTHER connected clients
                const broadcastData = {
                    "status": "1",
                    "payload": {
                        'uuid': reqObj.uuid,
                        'lat': reqObj.lat,
                        'long': reqObj.long,
                        'degree': degree.toString(), // Ensure it's a string
                        'timestamp': new Date().toISOString()
                    }
                };

                // If socket_id is provided, exclude that socket from broadcast
                if (reqObj.socket_id && reqObj.socket_id !== '') {
                    broadcastCarUpdate(reqObj.socket_id, "car_update_location", broadcastData);
                } else {
                    // If no socket_id, broadcast to all
                    io.emit("car_update_location", broadcastData);
                }

                helper.Dlog("Broadcasted car_update_location event");

                res.json({
                    "status": "1",
                    "message": msg_success,
                    "timestamp": new Date().toISOString()
                });

            } catch (error) {
                helper.Dlog("Error in car_update_location: " + error.message);
                res.json({ "status": "0", "message": "Error processing location update: " + error.message });
            }
        });
    });

    // Helper function to clean up inactive cars
    function cleanupInactiveCars() {
        const currentTime = Date.now();
        const INACTIVE_THRESHOLD = 5 * 60 * 1000; // 5 minutes

        Object.keys(car_location_obj).forEach(uuid => {
            const car = car_location_obj[uuid];
            if (car.lastUpdate && (currentTime - car.lastUpdate) > INACTIVE_THRESHOLD) {
                helper.Dlog(`Removing inactive car: ${uuid}`);
                delete car_location_obj[uuid];

                // Notify all clients about car removal
                io.emit("car_removed", {
                    "status": "1",
                    "payload": {
                        "uuid": uuid
                    }
                });
            }
        });
    }

    // Run cleanup every 2 minutes
    setInterval(cleanupInactiveCars, 2 * 60 * 1000);

    app.post('/api/car_join', (req, res) => {
        helper.Dlog("=== CAR JOIN REQUEST ===");
        helper.Dlog(req.body);

        var reqObj = req.body;
        helper.CheckParameterValid(res, reqObj, ['uuid', 'lat', 'long', 'degree'], () => {
            try {
                const socketId = reqObj.socket_id || 'http_only';

                // Update socket list if socket_id is provided
                if (reqObj.socket_id && reqObj.socket_id !== '') {
                    socket_list['us_' + reqObj.uuid] = {
                        'socket_id': reqObj.socket_id,
                        'joined_at': new Date().toISOString()
                    };
                    helper.Dlog(`Updated socket list for UUID: ${reqObj.uuid}, Socket ID: ${reqObj.socket_id}`);
                }

                // Store/update car location with timestamp
                car_location_obj[reqObj.uuid] = {
                    'uuid': reqObj.uuid,
                    'lat': parseFloat(reqObj.lat),
                    'long': parseFloat(reqObj.long),
                    'degree': parseFloat(reqObj.degree),
                    'lastUpdate': Date.now(),
                    'socket_id': socketId,
                    'joined_at': new Date().toISOString()
                };

                helper.Dlog(`Car location stored for UUID: ${reqObj.uuid}`);
                helper.Dlog(`Total cars tracked: ${Object.keys(car_location_obj).length}`);

                // Broadcast to all OTHER connected clients (not the sender)
                const broadcastData = {
                    "status": "1",
                    "payload": {
                        'uuid': reqObj.uuid,
                        'lat': reqObj.lat,
                        'long': reqObj.long,
                        'degree': reqObj.degree,
                        'timestamp': new Date().toISOString()
                    }
                };

                // If socket_id is provided, exclude that socket from broadcast
                if (reqObj.socket_id && reqObj.socket_id !== '') {
                    broadcastCarUpdate(reqObj.socket_id, "car_join", broadcastData);
                } else {
                    // If no socket_id, broadcast to all
                    io.emit("car_join", broadcastData);
                }

                helper.Dlog("Broadcasted car_join event");

                // Return ALL cars to the joining client (so they can see existing cars)
                const responsePayload = {};
                Object.keys(car_location_obj).forEach(uuid => {
                    const car = car_location_obj[uuid];
                    responsePayload[uuid] = {
                        'uuid': car.uuid,
                        'lat': car.lat,
                        'long': car.long,
                        'degree': car.degree,
                        'lastUpdate': car.lastUpdate
                    };
                });

                res.json({
                    "status": "1",
                    "payload": responsePayload,
                    "message": msg_success,
                    "total_cars": Object.keys(car_location_obj).length
                });

                helper.Dlog(`Sent response with ${Object.keys(responsePayload).length} cars`);

            } catch (error) {
                helper.Dlog("Error in car_join: " + error.message);
                res.json({ "status": "0", "message": "Error processing car join: " + error.message });
            }
        });
    });

    app.post('/api/car_update_location', (req, res) => {
        helper.Dlog("=== CAR LOCATION UPDATE ===");
        helper.Dlog(req.body);

        var reqObj = req.body;
        helper.CheckParameterValid(res, reqObj, ['uuid', 'lat', 'long', 'degree'], () => {
            try {
                const socketId = reqObj.socket_id || 'http_only';

                // Update socket list if socket_id is provided
                if (reqObj.socket_id && reqObj.socket_id !== '') {
                    socket_list['us_' + reqObj.uuid] = {
                        'socket_id': reqObj.socket_id,
                        'last_update': new Date().toISOString()
                    };
                }

                // Update car location with timestamp
                car_location_obj[reqObj.uuid] = {
                    'uuid': reqObj.uuid,
                    'lat': parseFloat(reqObj.lat),
                    'long': parseFloat(reqObj.long),
                    'degree': parseFloat(reqObj.degree),
                    'lastUpdate': Date.now(),
                    'socket_id': socketId,
                    'updated_at': new Date().toISOString()
                };

                helper.Dlog(`Updated location for UUID: ${reqObj.uuid} - Lat: ${reqObj.lat}, Long: ${reqObj.long}, Degree: ${reqObj.degree}`);

                // Broadcast to all OTHER connected clients
                const broadcastData = {
                    "status": "1",
                    "payload": {
                        'uuid': reqObj.uuid,
                        'lat': reqObj.lat,
                        'long': reqObj.long,
                        'degree': reqObj.degree,
                        'timestamp': new Date().toISOString()
                    }
                };

                // If socket_id is provided, exclude that socket from broadcast
                if (reqObj.socket_id && reqObj.socket_id !== '') {
                    broadcastCarUpdate(reqObj.socket_id, "car_update_location", broadcastData);
                } else {
                    // If no socket_id, broadcast to all
                    io.emit("car_update_location", broadcastData);
                }

                helper.Dlog("Broadcasted car_update_location event");

                res.json({
                    "status": "1",
                    "message": msg_success,
                    "timestamp": new Date().toISOString()
                });

            } catch (error) {
                helper.Dlog("Error in car_update_location: " + error.message);
                res.json({ "status": "0", "message": "Error processing location update: " + error.message });
            }
        });
    });

    // Add endpoint to get current car locations (useful for debugging)
    app.get('/api/car_locations', (req, res) => {
        helper.Dlog("=== GET CAR LOCATIONS ===");
        res.json({
            "status": "1",
            "payload": car_location_obj,
            "total_cars": Object.keys(car_location_obj).length,
            "timestamp": new Date().toISOString()
        });
    });

    // Add endpoint to remove a specific car (useful for testing)
    app.post('/api/car_remove', (req, res) => {
        helper.Dlog("=== CAR REMOVE REQUEST ===");
        helper.Dlog(req.body);

        var reqObj = req.body;
        helper.CheckParameterValid(res, reqObj, ['uuid'], () => {
            try {
                if (car_location_obj[reqObj.uuid]) {
                    delete car_location_obj[reqObj.uuid];
                    delete socket_list['us_' + reqObj.uuid];

                    // Notify all clients about car removal
                    io.emit("car_removed", {
                        "status": "1",
                        "payload": {
                            "uuid": reqObj.uuid,
                            "timestamp": new Date().toISOString()
                        }
                    });

                    res.json({
                        "status": "1",
                        "message": "Car removed successfully"
                    });

                    helper.Dlog(`Removed car: ${reqObj.uuid}`);
                } else {
                    res.json({
                        "status": "0",
                        "message": "Car not found"
                    });
                }
            } catch (error) {
                helper.Dlog("Error in car_remove: " + error.message);
                res.json({ "status": "0", "message": "Error removing car: " + error.message });
            }
        });
    });

    // Handle socket disconnections
    io.on('connection', (socket) => {
        helper.Dlog(`New socket connected: ${socket.id}`);

        socket.on('disconnect', (reason) => {
            helper.Dlog(`Socket disconnected: ${socket.id}, Reason: ${reason}`);

            // Find and remove cars associated with this socket
            Object.keys(car_location_obj).forEach(uuid => {
                const car = car_location_obj[uuid];
                if (car.socket_id === socket.id) {
                    helper.Dlog(`Removing car ${uuid} due to socket disconnect`);
                    delete car_location_obj[uuid];
                    delete socket_list['us_' + uuid];

                    // Notify other clients
                    socket.broadcast.emit("car_removed", {
                        "status": "1",
                        "payload": {
                            "uuid": uuid,
                            "reason": "socket_disconnect",
                            "timestamp": new Date().toISOString()
                        }
                    });
                }
            });
        });
    });

    helper.Dlog("Car controller initialized successfully");
}