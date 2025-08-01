var createError = require('http-errors');
var express = require('express');
var path = require('path');
var cookieParser = require('cookie-parser');
var logger = require('morgan');

const cors = require('cors');
const fs = require('fs');

var app = express();

var server = require('http').createServer(app);

// Enhanced Socket.IO configuration for Google Cloud App Engine
var io = require('socket.io')(server, {
  cors: {
    origin: "*", // Allow all origins for development - restrict this in production
    methods: ["GET", "POST"],
    credentials: false,
    allowEIO3: true // Enable Engine.IO v3 compatibility
  },
  allowEIO3: true,
  transports: ['polling', 'websocket'], // Start with polling, then upgrade
  pingTimeout: 60000, // 60 seconds
  pingInterval: 25000, // 25 seconds
  upgradeTimeout: 30000, // 30 seconds
  maxHttpBufferSize: 1e8, // 100 MB
  allowUpgrades: true,
  cookie: false, // Disable cookies for better cloud compatibility
  serveClient: true, // Serve the Socket.IO client
  path: '/socket.io/' // Explicit path
});

// Use the port provided by GCP or default to 8080 (GCP standard)
var serverPort = process.env.PORT || 8080;

var user_socket_connect_list = [];

// view engine setup
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'ejs');

// Trust proxy for Google Cloud App Engine
app.set('trust proxy', true);

app.use(logger('dev'));
app.use(express.json({limit: '100mb'}));
app.use(express.urlencoded({ extended: true, limit: '100mb' }));
app.use(cookieParser());
app.use(express.static(path.join(__dirname, 'public')));

// Enhanced CORS options for cloud deployment
const corsOptions = {
  origin: "*", // Allow all origins for development - restrict this in production
  credentials: false,
  methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
  allowedHeaders: ["Content-Type", "Authorization", "X-Requested-With", "Accept", "Origin"],
  preflightContinue: false,
  optionsSuccessStatus: 204
};

app.use(cors(corsOptions));

// Add preflight OPTIONS handler for all routes
app.options('*', cors(corsOptions));

// Add a basic health check endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Charging Station Backend is running!',
    timestamp: new Date().toISOString(),
    port: serverPort,
    environment: process.env.NODE_ENV || 'development',
    socketIO: 'enabled'
  });
});

// Add Socket.IO test endpoint
app.get('/socket-test', (req, res) => {
  res.json({
    message: 'Socket.IO is configured',
    connectedClients: user_socket_connect_list.length,
    timestamp: new Date().toISOString()
  });
});

// Check if controllers directory exists before reading
if (fs.existsSync('./controllers')) {
  fs.readdirSync('./controllers').forEach( (file) => {
    if(file.substr(-3) == ".js") {
      route = require('./controllers/' + file);
      route.controller(app, io, user_socket_connect_list);
    }
  });
} else {
  console.log('Controllers directory not found. Creating basic API endpoints...');

  // Add basic API endpoints if controllers don't exist
  app.post('/api/car_join', (req, res) => {
    console.log('Car join request:', req.body);
    res.json({ status: 'success', message: 'Car joined successfully' });
  });

  app.post('/api/car_update_location', (req, res) => {
    console.log('Location update:', req.body);
    res.json({ status: 'success', message: 'Location updated successfully' });
  });
}

// Enhanced Socket.IO connection handling
io.on('connection', (socket) => {
  console.log('New client connected:', socket.id, 'Total clients:', io.engine.clientsCount);

  // Add to connected users list
  user_socket_connect_list.push({
    socketId: socket.id,
    connectedAt: new Date().toISOString(),
    uuid: null
  });

  // Send connection confirmation
  socket.emit('connected', {
    socketId: socket.id,
    message: 'Connected to charging station server',
    timestamp: new Date().toISOString()
  });

  socket.on('UpdateSocket', (data) => {
    console.log('UpdateSocket received:', data);
    try {
      const parsedData = typeof data === 'string' ? JSON.parse(data) : data;
      console.log('UUID:', parsedData.uuid);

      // Update the user in the connected list
      const userIndex = user_socket_connect_list.findIndex(user => user.socketId === socket.id);
      if (userIndex !== -1) {
        user_socket_connect_list[userIndex].uuid = parsedData.uuid;
        user_socket_connect_list[userIndex].lastUpdate = new Date().toISOString();
      }

      // Send confirmation back to client
      socket.emit('UpdateSocket', {
        status: 'success',
        socketId: socket.id,
        uuid: parsedData.uuid,
        timestamp: new Date().toISOString()
      });

      console.log('Socket updated for UUID:', parsedData.uuid);
    } catch (e) {
      console.log('Error parsing UpdateSocket data:', e);
      socket.emit('UpdateSocket', {
        status: 'error',
        message: 'Invalid data format',
        timestamp: new Date().toISOString()
      });
    }
  });

  // Handle location updates
  socket.on('location_update', (data) => {
    console.log('Location update received:', data);
    try {
      const parsedData = typeof data === 'string' ? JSON.parse(data) : data;

      // Broadcast location to other connected clients if needed
      socket.broadcast.emit('location_broadcast', {
        uuid: parsedData.uuid,
        latitude: parsedData.latitude,
        longitude: parsedData.longitude,
        timestamp: new Date().toISOString()
      });

      // Confirm receipt
      socket.emit('location_confirmed', {
        status: 'success',
        timestamp: new Date().toISOString()
      });
    } catch (e) {
      console.log('Error handling location update:', e);
    }
  });

  socket.on('disconnect', (reason) => {
    console.log('Client disconnected:', socket.id, 'Reason:', reason, 'Remaining clients:', io.engine.clientsCount);

    // Remove from connected users list
    user_socket_connect_list = user_socket_connect_list.filter(user => user.socketId !== socket.id);
  });

  socket.on('error', (error) => {
    console.log('Socket error:', error);
  });
});

// Handle server errors
server.on('error', (error) => {
  console.error('Server error:', error);
});

// Graceful shutdown handling
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});

// catch 404 and forward to error handler
app.use(function(req, res, next) {
  next(createError(404));
});

// error handler
app.use(function(err, req, res, next) {
  // set locals, only providing error in development
  res.locals.message = err.message;
  res.locals.error = req.app.get('env') === 'development' ? err : {};

  console.error('Error:', err);

  // render the error page
  res.status(err.status || 500);
  if (req.accepts('json')) {
    res.json({ error: err.message });
  } else {
    res.render('error');
  }
});

// Start the server
server.listen(serverPort, () => {
  console.log("===========================================");
  console.log("🚀 Charging Station Server Started");
  console.log("Port:", serverPort);
  console.log("Environment:", process.env.NODE_ENV || 'development');
  console.log("Socket.IO: Enabled");
  console.log("Time:", new Date().toISOString());
  console.log("===========================================");
});

module.exports = app;