import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import '../models/request_model.dart';
// No need for additional imports

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = 
      FlutterLocalNotificationsPlugin();
  
  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  Future<void> initialize() async {
    debugPrint('Initializing notification service...');
    await requestNotificationPermission();
    // Create notification channels for Android
    if (Platform.isAndroid) {
      debugPrint('Setting up Android notification channels...');
      const AndroidNotificationChannel nearbyRequestsChannel = AndroidNotificationChannel(
        'nearby_requests_channel',
        'Nearby Requests',
        description: 'Notifications for nearby SOS requests',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      const AndroidNotificationChannel statusChangeChannel = AndroidNotificationChannel(
        'status_change_channel',
        'Status Changes',
        description: 'Notifications for request status changes',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(nearbyRequestsChannel);

      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(statusChangeChannel);
    }

    // Initialize settings for Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Initialize settings for iOS
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    
    // Initialize settings for all platforms
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        debugPrint('Notification clicked with payload: ${response.payload}');
      },
    );
  }

  // Request notification permissions for both Android and iOS
Future<void> requestNotificationPermission() async {
  if (Platform.isAndroid) {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
        FlutterLocalNotificationsPlugin();
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }
}

  // Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final bool? areEnabled = await androidImplementation?.areNotificationsEnabled();
      debugPrint('Notifications enabled: $areEnabled');
      return areEnabled ?? false;
    }
    return true; // For iOS, we assume enabled if permissions were granted
  }

  // Show notification for nearby request
  Future<void> showNearbyRequestNotification(Request request, double distance) async {
    debugPrint('Preparing to show nearby request notification...');
    try {
      debugPrint('Setting up Android notification details...');
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'nearby_requests_channel',
        'Nearby Requests',
        channelDescription: 'Notifications for nearby SOS requests',
        importance: Importance.max,
        priority: Priority.max,
        enableVibration: true,
        playSound: true,
        showWhen: true,
        icon: '@mipmap/ic_launcher',  // Explicitly set the notification icon
        channelShowBadge: true,
      );
    
      debugPrint('Setting up iOS notification details...');
      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
    
      debugPrint('Combining platform-specific notification details...');
      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );
    
      // Format distance to be more readable
      String formattedDistance = distance >= 1000 
          ? '${(distance / 1000).toStringAsFixed(1)} km' 
          : '${distance.toStringAsFixed(0)} m';
      
      debugPrint('Attempting to show notification with ID: ${request.hashCode}');
      await _flutterLocalNotificationsPlugin.show(
        request.hashCode, // Use request hashcode as notification ID
        'Nearby ${request.requestType.name} Request',
        'A request is ${formattedDistance} away at ${request.location.placeName}',
        platformChannelSpecifics,
        payload: request.id,
      );
      debugPrint('Successfully showed notification for request: ${request.id}');
    } catch(e, stackTrace) {
      debugPrint('Error showing nearby request notification: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('Request details: ID=${request.id}, Type=${request.requestType.name}, Distance=$distance');
    }
  }
  // Show notification for request status change
  Future<void> showStatusChangeNotification(Request request) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'status_change_channel',
      'Status Changes',
      channelDescription: 'Notifications for request status changes',
      importance: Importance.high,
      priority: Priority.high,
    );
    
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );
    
    String title = 'Request Status Updated';
    String body = 'Your request status has changed to ${request.status.name}';
    
    await _flutterLocalNotificationsPlugin.show(
      request.hashCode, // Use request hashcode as notification ID
      title,
      body,
      platformChannelSpecifics,
      payload: request.id,
    );
  }

  // Calculate if SOS has arrived at driver location
  bool hasArrivedAtDestination(double sosLat, double sosLng, 
                              double driverLat, double driverLng) {
    // Calculate distance between SOS and driver
    double distanceInMeters = Geolocator.distanceBetween(
      sosLat,
      sosLng,
      driverLat,
      driverLng,
    );
    
    // Log the distance for debugging
    print('Distance to destination: $distanceInMeters meters');
    
    // Consider arrived if within 50 meters
    return distanceInMeters <= 50;
  }
}
