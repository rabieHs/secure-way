import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:secure_way_client/driver/interfaces/profile_tab.dart';
import 'package:secure_way_client/services/authentication_services.dart';
import 'package:secure_way_client/services/request_services.dart';
import 'package:secure_way_client/services/sos_location_service.dart';
import 'package:secure_way_client/services/notification_service.dart';
import '../../models/request_model.dart';
import '../../models/user_model.dart';
import 'dart:async';

// Add this constant at the top of your file
const String GOOGLE_API_KEY =
    "AIzaSyAGf0VB5bufPCJpUGbbteig5_yXRoJafqo"; // Replace with your API key

class MechanicHomeScreen extends StatefulWidget {
  final UserModel? user; // Accept user model if needed for profile tab
  const MechanicHomeScreen({super.key, this.user});

  @override
  _MechanicHomeScreenState createState() => _MechanicHomeScreenState();
}

class _MechanicHomeScreenState extends State<MechanicHomeScreen> {
  int _selectedIndex = 0;
  final RequestService _requestService = RequestService();
  final SosLocationService _locationService =
      SosLocationService(); // Renamed for clarity
  final PolylinePoints _polylinePoints = PolylinePoints();
  final NotificationService _notificationService =
      NotificationService(); // Add notification service instance

  double? _mechanicLatitude;
  double? _mechanicLongitude;
  String _currentLocationText = 'Locating...';
  bool _locationStreamInitialized = false;
  Stream<List<Request>>? _nearbyMechanicRequestStream; // Renamed stream

  // Google Maps related variables
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Map<PolylineId, Polyline> _polylines = {};
  Request? _selectedRequest;
  bool _routeDisplayed = false;
  List<LatLng> _routeCoordinates = [];
  Timer? _routeUpdateTimer;

  @override
  void initState() {
    super.initState();
    _initNotifications(); // Initialize notifications
    if (!_locationStreamInitialized) {
      _initLocationStream();
      _locationStreamInitialized = true;
    }
    _listenToRequestStatusChanges(); // Listen for status changes relevant to the mechanic
  }

  Future<void> _initNotifications() async {
    await _notificationService.initialize();
    await _notificationService.requestNotificationPermission();
  }

  // Listen to request status changes relevant to the mechanic (e.g., if they accepted a request)
  void _listenToRequestStatusChanges() async {
    // This might need adjustment based on how mechanics interact with requests.
    // For now, it mirrors the SOS screen's logic but might need refinement.
    final user = await AuthenticationService().getCurrentUserModel();
    if (user == null || user.userType != 'mechanic') return;

    // Example: Listen to requests assigned to this mechanic (if applicable)
    // Or listen to all mechanic requests and filter locally if needed.
    // This part depends heavily on the backend logic for assigning requests to mechanics.
    // For simplicity, we'll keep listening to the user's own requests for now,
    // assuming a mechanic might also *make* requests (unlikely but covers the base).
    // A more robust solution would involve querying requests assigned to this mechanic's ID.
    _requestService.getRequestsByUserIdSorted(user.uid).listen((requests) {
      for (var request in requests) {
        // Notify if a request they are involved in (e.g., accepted) changes status
        if (request.status == RequestStatus.accepted) {
          // Example condition
          _notificationService.showStatusChangeNotification(request);
        }
      }
    });
  }

  void _initLocationStream() {
    _locationService.locationStream.listen((locationData) async {
      print("Mechanic location data: $locationData");
      double? newLat = locationData['latitude'];
      double? newLng = locationData['longitude'];
      String newAddress = locationData['address'] ?? 'Location unavailable';
      final UserModel? user =
          await AuthenticationService().getCurrentUserModel();

      if (newLat != null && newLng != null) {
        bool locationChanged = newLat != _mechanicLatitude ||
            newLng != _mechanicLongitude ||
            _mechanicLatitude == null;

        setState(() {
          _currentLocationText = newAddress;
          _mechanicLatitude = newLat;
          _mechanicLongitude = newLng;
        });

        if (locationChanged) {
          // Ensure we fetch Mechanic requests
          RequestType currentRequestType =
              RequestType.mechanic; // Hardcoded for mechanic screen
          print(
              "Fetching mechanic requests near: $_mechanicLatitude, $_mechanicLongitude");

          // Update the stream with the new location and mechanic type
          setState(() {
            _nearbyMechanicRequestStream =
                _requestService.getNearbyRequestsByType(currentRequestType,
                    _mechanicLatitude!, _mechanicLongitude!);
          });

          // Move camera to current location on first load or if not navigating
          if (_mapController != null && !_routeDisplayed) {
            _mapController!.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: LatLng(_mechanicLatitude!, _mechanicLongitude!),
                  zoom: 14.0,
                ),
              ),
            );
          }

          // Update polyline if navigating
          if (_selectedRequest != null && _routeDisplayed) {
            _getRouteToSelectedRequest();
            // Check if mechanic has arrived
            if (_selectedRequest!.status == RequestStatus.accepted) {
              _checkIfArrivedAtDestination();
            }
          }
        } else if (_currentLocationText != newAddress) {
          // Update address even if lat/lng are the same
          setState(() {
            _currentLocationText = newAddress;
          });
        }
      }
    });
  }

  // Check if Mechanic has arrived at the destination
  void _checkIfArrivedAtDestination() {
    if (_selectedRequest == null ||
        _mechanicLatitude == null ||
        _mechanicLongitude == null) {
      return;
    }

    bool hasArrived = _notificationService.hasArrivedAtDestination(
        _mechanicLatitude!,
        _mechanicLongitude!,
        _selectedRequest!.location.latitude,
        _selectedRequest!.location.longitude);

    if (hasArrived) {
      print('Mechanic arrived at destination! Updating request status...');

      // Close navigation mode first (remove polylines and stop navigation)
      _stopNavigation();

      // Then update the request status to completed
      _requestService.updateRequestStatus(
          _selectedRequest!.id, RequestStatus.completed);

      // Show notification to the user who made the request
      _notificationService.showStatusChangeNotification(_selectedRequest!);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'You have arrived at the destination. Request marked as completed.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // Stop navigation mode and clear polylines
  void _stopNavigation() {
    setState(() {
      _routeDisplayed = false;
      _polylines.clear();
      _routeCoordinates.clear();
      _selectedRequest = null;

      // Force full map refresh and markers update
      if (_mapController != null &&
          _mechanicLatitude != null &&
          _mechanicLongitude != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(_mechanicLatitude!, _mechanicLongitude!),
              zoom: 14.0,
            ),
          ),
        );
      }
    });

    // Cancel route update timer
    _routeUpdateTimer?.cancel();
  }

  void _updateMarkers(List<Request> requests) {
    Set<Marker> newMarkers = {};

    // Add marker for mechanic's current location
    if (_mechanicLatitude != null && _mechanicLongitude != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(_mechanicLatitude!, _mechanicLongitude!),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen), // Different color for mechanic
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );
    }

    // Add markers for each mechanic request
    for (var request in requests) {
      // Only add markers for mechanic requests that are pending
      if (request.requestType == RequestType.mechanic &&
          request.status == RequestStatus.pending) {
        newMarkers.add(
          Marker(
            markerId: MarkerId(request.id),
            position:
                LatLng(request.location.latitude, request.location.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor
                .hueOrange), // Different color for mechanic requests
            infoWindow: InfoWindow(
              title: 'Mechanic Request',
              snippet: 'Tap for details', // Keep snippet concise
            ),
            onTap: () {
              setState(() {
                _selectedRequest = request;
                _showRequestDetailsBottomSheet(request);
              });
            },
          ),
        );
      }
    }

    // Ensure selected request marker persists during navigation
    if (_selectedRequest != null && _routeDisplayed) {
      bool selectedMarkerExists =
          newMarkers.any((m) => m.markerId.value == _selectedRequest!.id);
      if (!selectedMarkerExists) {
        newMarkers.add(
          Marker(
            markerId: MarkerId(_selectedRequest!.id),
            position: LatLng(_selectedRequest!.location.latitude,
                _selectedRequest!.location.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange),
            infoWindow: InfoWindow(
              title: 'Destination',
              snippet: _selectedRequest!.location.placeName ?? 'N/A',
            ),
          ),
        );
      }
    }

    // Use setState to update the markers on the map
    if (mounted) {
      // Check if the widget is still in the tree
      setState(() {
        _markers = newMarkers;
      });
    }
  }

  void _showRequestDetailsBottomSheet(Request request) {
    final TextEditingController quickResponseController =
        TextEditingController();
    bool isProvidingQuickResponse = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          // Use StatefulBuilder for local state management in the sheet
          builder: (BuildContext context, StateSetter setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.45, // Adjusted size
              minChildSize: 0.2,
              maxChildSize: 0.7, // Adjusted size
              expand: false,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(
                          // Handle for dragging
                          child: Container(
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Mechanic Request Details', // Updated title
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 10),
                        _buildDetailRow('Request ID:', request.id),
                        _buildDetailRow(
                            'Location:', request.location.placeName ?? 'N/A'),
                        // Display Car Brand and Model if available
                        if (request.carBrand != null &&
                            request.carBrand!.isNotEmpty)
                          _buildDetailRow('Car Brand:', request.carBrand!),
                        if (request.carModel != null &&
                            request.carModel!.isNotEmpty)
                          _buildDetailRow('Car Model:', request.carModel!),
                        _buildDetailRow('Description:', request.description),
                        _buildDetailRow('Status:', request.status.name),
                        const SizedBox(height: 15),

                        // Quick response section (optional for mechanics, kept for consistency)
                        Row(
                          children: [
                            Checkbox(
                              value: isProvidingQuickResponse,
                              onChanged: (value) {
                                setModalState(() {
                                  // Use setModalState to update sheet's state
                                  isProvidingQuickResponse = value ?? false;
                                });
                              },
                            ),
                            const Text(
                              'Provide quick response without traveling',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        if (isProvidingQuickResponse) ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: quickResponseController,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              hintText:
                                  'Enter your quick solution or advice...',
                              border: OutlineInputBorder(),
                              labelText: 'Quick Response',
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(
                                  context); // Close bottom sheet first
                              if (isProvidingQuickResponse) {
                                _replyToRequest(
                                    request, quickResponseController.text);
                              } else {
                                _acceptRequest(request);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                foregroundColor: Colors.white),
                            child: Text(isProvidingQuickResponse
                                ? 'Send Reply'
                                : 'Accept Request'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _acceptRequest(Request request) {
    if (!mounted) return; // Check if widget is still mounted
    setState(() {
      _selectedRequest = request;
      _routeDisplayed = true;
    });

    _getRouteToSelectedRequest();

    // Update request status in Firestore
    _requestService.updateRequestStatus(request.id, RequestStatus.accepted);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Request accepted - navigating to location'),
        backgroundColor: Colors.green,
      ),
    );

    // Start timer to update route periodically
    _routeUpdateTimer?.cancel();
    _routeUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_routeDisplayed && _selectedRequest != null && mounted) {
        _getRouteToSelectedRequest();
      } else {
        timer.cancel();
      }
    });
  }

  void _replyToRequest(Request request, String response) {
    // Update request status and add response in Firestore
    _requestService.updateRequestWithResponse(request.id, response);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Quick response sent to driver'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _getRouteToSelectedRequest() async {
    if (!mounted ||
        _selectedRequest == null ||
        _mechanicLatitude == null ||
        _mechanicLongitude == null) {
      return;
    }

    try {
      PolylineResult result = await _polylinePoints.getRouteBetweenCoordinates(
        request: PolylineRequest(
            origin: PointLatLng(_mechanicLatitude!, _mechanicLongitude!),
            destination: PointLatLng(_selectedRequest!.location.latitude,
                _selectedRequest!.location.longitude),
            mode: TravelMode.driving),
        googleApiKey: GOOGLE_API_KEY,
      );

      if (result.points.isNotEmpty && mounted) {
        _routeCoordinates = result.points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();

        final String polylineIdVal = 'polyline_${_selectedRequest!.id}';
        final PolylineId polylineId = PolylineId(polylineIdVal);

        final Polyline polyline = Polyline(
          polylineId: polylineId,
          color: Colors.blue, // Route color
          width: 5,
          points: _routeCoordinates,
        );

        setState(() {
          _polylines[polylineId] = polyline;
        });

        _adjustCameraToShowRoute();
      } else if (mounted) {
        print("Failed to get route points: ${result.errorMessage}");
        _createDirectPolyline(); // Fallback to direct line
      }
    } catch (e) {
      print("Error getting route: $e");
      if (mounted) {
        _createDirectPolyline(); // Fallback on error
      }
    }
  }

  void _createDirectPolyline() {
    if (!mounted ||
        _selectedRequest == null ||
        _mechanicLatitude == null ||
        _mechanicLongitude == null) {
      return;
    }

    final String polylineIdVal = 'polyline_${_selectedRequest!.id}';
    final PolylineId polylineId = PolylineId(polylineIdVal);

    final Polyline polyline = Polyline(
      polylineId: polylineId,
      color: Colors.red, // Indicate direct line
      width: 5,
      points: [
        LatLng(_mechanicLatitude!, _mechanicLongitude!),
        LatLng(_selectedRequest!.location.latitude,
            _selectedRequest!.location.longitude),
      ],
    );

    setState(() {
      _polylines[polylineId] = polyline;
    });

    _adjustCameraToShowRoute();
  }

  void _adjustCameraToShowRoute() {
    if (_mapController == null || !mounted) return;

    LatLngBounds bounds;
    List<LatLng> pointsToBound = [];

    // Include current location and destination
    if (_mechanicLatitude != null && _mechanicLongitude != null) {
      pointsToBound.add(LatLng(_mechanicLatitude!, _mechanicLongitude!));
    }
    if (_selectedRequest != null) {
      pointsToBound.add(LatLng(_selectedRequest!.location.latitude,
          _selectedRequest!.location.longitude));
    }

    // Add route coordinates if available
    if (_routeCoordinates.isNotEmpty) {
      pointsToBound.addAll(_routeCoordinates);
    }

    if (pointsToBound.length < 2)
      return; // Need at least two points to create bounds

    bounds = _createBoundsFromList(pointsToBound);

    _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 60)); // Increased padding
  }

  LatLngBounds _createBoundsFromList(List<LatLng> points) {
    double? x0, x1, y0, y1;
    for (LatLng point in points) {
      if (x0 == null) {
        x0 = x1 = point.latitude;
        y0 = y1 = point.longitude;
      } else {
        if (point.latitude > x1!) x1 = point.latitude;
        if (point.latitude < x0) x0 = point.latitude;
        if (point.longitude > y1!) y1 = point.longitude;
        if (point.longitude < y0!) y0 = point.longitude;
      }
    }
    // Add a small padding to prevent markers from being exactly on the edge
    double padding = 0.001;
    return LatLngBounds(
      northeast: LatLng(x1! + padding, y1! + padding),
      southwest: LatLng(x0! - padding, y0! - padding),
    );
  }

  // This function might not be strictly necessary if the screen is only for mechanics,
  // but kept for potential future use or if the base class requires it.
  RequestType _getRequestTypeFromUser(UserModel? user) {
    // For MechanicHomeScreen, we always want mechanic requests.
    return RequestType.mechanic;
  }

  void _onItemTapped(int index) {
    if (!mounted) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Determine which widgets to show based on the selected index
    final List<Widget> widgetOptions = <Widget>[
      _buildMapAndRequestsView(), // Index 0: Map view
      ProfileTab(user: widget.user), // Index 1: Profile view
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mechanic Home'), // Updated title
      ),
      body: IndexedStack(
        // Use IndexedStack to keep state of tabs
        index: _selectedIndex,
        children: widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.map), // Changed icon to map
            label: 'Requests Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  // Extracted map and request view logic into a separate builder method
  Widget _buildMapAndRequestsView() {
    return Column(
      children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Mechanic Current Location: $_currentLocationText', // Updated text
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Request>>(
            stream: _nearbyMechanicRequestStream, // Use mechanic stream
            builder: (context, snapshot) {
              if (_nearbyMechanicRequestStream == null ||
                  snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: _mechanicLatitude == null
                      ? const Text("Waiting for location...")
                      : const CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                print("Stream error: ${snapshot.error}"); // Log error
                return Center(
                    child: Text('Error loading requests: ${snapshot.error}'));
              }

              List<Request> mechanicRequests = snapshot.data ?? [];
              // Filter again just to be sure (stream should already be filtered by service)
              mechanicRequests = mechanicRequests
                  .where((r) => r.requestType == RequestType.mechanic)
                  .toList();

              // Update markers in post frame callback to avoid setState during build
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  // Check if mounted before updating markers
                  _updateMarkers(mechanicRequests);
                }
              });

              // Build the map, show message if no requests
              return Stack(
                // Use Stack to potentially overlay info later
                children: [
                  _buildGoogleMap(mechanicRequests),
                  if (mechanicRequests.isEmpty &&
                      !snapshot.hasError &&
                      snapshot.connectionState == ConnectionState.active)
                    const Center(
                        child: Text('No nearby mechanic requests found.'))
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleMap(List<Request> requests) {
    // Initial camera position focuses on the mechanic's location if available
    CameraPosition initialCameraPosition = (_mechanicLatitude != null &&
            _mechanicLongitude != null)
        ? CameraPosition(
            target: LatLng(_mechanicLatitude!, _mechanicLongitude!),
            zoom: 14.0,
          )
        : const CameraPosition(
            // Default position if location is not yet available
            target: LatLng(36.8065, 10.1815), // Tunis coordinates as fallback
            zoom: 11.0,
          );

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: initialCameraPosition,
          myLocationEnabled: true, // Show mechanic's blue dot
          myLocationButtonEnabled: true, // Button to center on mechanic
          markers: _markers,
          polylines: Set<Polyline>.of(_polylines.values),
          onMapCreated: (GoogleMapController controller) {
            if (mounted) {
              _mapController = controller;
              // Move camera to current location once map is created if available
              if (_mechanicLatitude != null &&
                  _mechanicLongitude != null &&
                  !_routeDisplayed) {
                _mapController!.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: LatLng(_mechanicLatitude!, _mechanicLongitude!),
                      zoom: 14.0,
                    ),
                  ),
                );
              }
            }
          },
          // Optional: Reset selected request when tapping on the map background
          onTap: (LatLng location) {
            if (mounted && !_routeDisplayed) {
              // Only reset if not actively navigating
              setState(() {
                _selectedRequest = null;
                // Optionally clear polylines if you want route to disappear on map tap
                // _polylines.clear();
              });
            }
          },
        ),

        // Show stop navigation button when in navigation mode
        if (_routeDisplayed)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: _stopNavigation,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Stop Navigation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 5,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _locationService.dispose(); // Dispose location service subscription
    _routeUpdateTimer?.cancel();
    // Note: _nearbyMechanicRequestStream is managed by StreamBuilder, no need to manually close here
    super.dispose();
  }
}
