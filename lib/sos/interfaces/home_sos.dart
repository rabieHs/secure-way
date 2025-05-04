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

class SosHomeScreen extends StatefulWidget {
  final UserModel? user;
  const SosHomeScreen({super.key, this.user});

  @override
  _SosHomeScreenState createState() => _SosHomeScreenState();
}

class _SosHomeScreenState extends State<SosHomeScreen> {
  int _selectedIndex = 0;
  final RequestService _requestService = RequestService();
  final SosLocationService _sosLocationService = SosLocationService();
  final PolylinePoints _polylinePoints = PolylinePoints();

  double? _driverLatitude;
  double? _driverLongitude;
  String _currentLocationText = 'Locating...';
  bool _locationStreamInitialized = false;
  Stream<List<Request>>? _nearbySosRequestStream;

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
    if (!_locationStreamInitialized) {
      _initLocationStream();
      _locationStreamInitialized = true;
    }
  }

  void _initLocationStream() {
    _sosLocationService.locationStream.listen((locationData) async {
      print("location data: $locationData");
      double? newLat = locationData['latitude'];
      double? newLng = locationData['longitude'];
      String newAddress = locationData['address'] ?? 'Location unavailable';
      final UserModel? user =
          await AuthenticationService().getCurrentUserModel();

      if (newLat != null && newLng != null) {
        bool locationChanged = newLat != _driverLatitude ||
            newLng != _driverLongitude ||
            _driverLatitude == null;

        setState(() {
          _currentLocationText = newAddress;
          _driverLatitude = newLat;
          _driverLongitude = newLng;
        });

        if (locationChanged) {
          RequestType currentRequestType = _getRequestTypeFromUser(user);
          print("current request type: $currentRequestType");

          // Update the stream with the new location and determined types
          setState(() {
            _nearbySosRequestStream = _requestService.getNearbyRequestsByType(
                currentRequestType, _driverLatitude!, _driverLongitude!);
          });

          // Move camera to current location on first load
          if (_mapController != null &&
              (_driverLatitude != null && _driverLongitude != null) &&
              !_routeDisplayed) {
            _mapController!.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: LatLng(_driverLatitude!, _driverLongitude!),
                  zoom: 14.0,
                ),
              ),
            );
          }

          // Update polyline if we have a selected request and route is being displayed
          if (_selectedRequest != null && _routeDisplayed) {
            _getRouteToSelectedRequest();

            // Check if SOS has arrived at the driver's location
            if (_selectedRequest!.status == RequestStatus.accepted) {
              _checkIfArrivedAtDestination();
            }
          }
        }
      }
    });
  }

  // Check if SOS has arrived at the destination and update status if needed
  void _checkIfArrivedAtDestination() {
    if (_selectedRequest == null ||
        _driverLatitude == null ||
        _driverLongitude == null) {
      return;
    }

    // Use the notification service to check if arrived
    final notificationService = NotificationService();
    bool hasArrived = notificationService.hasArrivedAtDestination(
        _driverLatitude!,
        _driverLongitude!,
        _selectedRequest!.location.latitude,
        _selectedRequest!.location.longitude);

    if (hasArrived) {
      print('Arrived at destination! Updating request status...');

      // Close navigation mode first (remove polylines and stop navigation)
      _stopNavigation();

      // Then update the request status to completed
      _requestService.updateRequestStatus(
          _selectedRequest!.id, RequestStatus.completed);

      // Show notification to the user who made the request
      notificationService.showStatusChangeNotification(_selectedRequest!);

      // Show notification and update UI
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
    // Store the request ID before clearing it
    String? requestId;
    if (_selectedRequest != null) {
      requestId = _selectedRequest!.id;

      // Update request status back to pending if it was accepted
      if (_selectedRequest!.status == RequestStatus.accepted) {
        _requestService.updateRequestStatus(requestId, RequestStatus.pending);

        // Show notification to the user
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Navigation stopped. Request returned to pending status.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    setState(() {
      _routeDisplayed = false;
      _polylines.clear();
      _routeCoordinates.clear();
      _selectedRequest = null;

      // Force full map refresh and markers update
      if (_mapController != null &&
          _driverLatitude != null &&
          _driverLongitude != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(_driverLatitude!, _driverLongitude!),
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

    // Add a marker for the current location (driver/user)
    if (_driverLatitude != null && _driverLongitude != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(_driverLatitude!, _driverLongitude!),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );
    }

    // Add markers for each request - only show pending requests
    for (var request in requests) {
      // Only show pending requests on the map
      if (request.status == RequestStatus.pending) {
        newMarkers.add(
          Marker(
            markerId: MarkerId(request.id),
            position:
                LatLng(request.location.latitude, request.location.longitude),
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(
              title: 'SOS Request',
              snippet: request.location.placeName ?? 'No address available',
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

    // Make sure the selected request marker is always visible when navigating
    // This ensures the destination marker doesn't disappear when navigation starts
    if (_selectedRequest != null && _routeDisplayed) {
      // Check if the selected request is not already in the markers set
      bool selectedRequestMarkerExists = false;
      for (var marker in newMarkers) {
        if (marker.markerId.value == _selectedRequest!.id) {
          selectedRequestMarkerExists = true;
          break;
        }
      }

      // If the selected request marker doesn't exist in the set, add it
      if (!selectedRequestMarkerExists) {
        newMarkers.add(
          Marker(
            markerId: MarkerId(_selectedRequest!.id),
            position: LatLng(_selectedRequest!.location.latitude,
                _selectedRequest!.location.longitude),
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(
              title: 'Destination',
              snippet: _selectedRequest!.location.placeName ??
                  'No address available',
            ),
          ),
        );
      }
    }

    setState(() {
      _markers = newMarkers;
    });
  }

  void _showRequestDetailsBottomSheet(Request request) {
    // Controller for the quick response text field
    final TextEditingController quickResponseController =
        TextEditingController();
    // Flag to track if the user is providing a quick response
    bool isProvidingQuickResponse = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.4, // Increased to accommodate the text field
              minChildSize: 0.2,
              maxChildSize: 0.6, // Increased for better UX when typing
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
                          'SOS Request Details',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 10),
                        _buildDetailRow('ID:', request.id),
                        _buildDetailRow(
                            'Location:', request.location.placeName ?? 'N/A'),
                        _buildDetailRow('Description:', request.description),
                        _buildDetailRow('Status:', request.status.name),
                        const SizedBox(height: 15),

                        // Quick response toggle
                        Row(
                          children: [
                            Checkbox(
                              value: isProvidingQuickResponse,
                              onChanged: (value) {
                                setModalState(() {
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

                        // Conditional quick response text field
                        if (isProvidingQuickResponse) ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: quickResponseController,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              hintText: 'Enter your quick solution...',
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
                              Navigator.pop(context);
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

  void _acceptRequest(Request request) {
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

    // Set up a timer to periodically update the route as the user moves
    _routeUpdateTimer?.cancel();
    _routeUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_routeDisplayed && _selectedRequest != null) {
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

  Future<void> _getRouteToSelectedRequest() async {
    if (_selectedRequest == null ||
        _driverLatitude == null ||
        _driverLongitude == null) {
      return;
    }

    try {
      // Get route points from Google Directions API
      PolylineResult result = await _polylinePoints.getRouteBetweenCoordinates(
        request: PolylineRequest(
            origin: PointLatLng(_driverLatitude!, _driverLongitude!),
            destination: PointLatLng(_selectedRequest!.location.latitude,
                _selectedRequest!.location.longitude),
            mode: TravelMode.driving),
        googleApiKey: GOOGLE_API_KEY,
      );

      if (result.points.isNotEmpty) {
        _routeCoordinates = result.points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();

        // Create or update the polyline
        final String polylineIdVal = 'polyline_${_selectedRequest!.id}';
        final PolylineId polylineId = PolylineId(polylineIdVal);

        final Polyline polyline = Polyline(
          polylineId: polylineId,
          color: Colors.blue,
          width: 5,
          points: _routeCoordinates,
        );

        setState(() {
          _polylines[polylineId] = polyline;
        });

        // Adjust camera to show the route
        _adjustCameraToShowRoute();
      } else {
        print("Failed to get route points: ${result.errorMessage}");
        // Fallback to direct line if route cannot be found
        _createDirectPolyline();
      }
    } catch (e) {
      print("Error getting route: $e");
      // Fallback to direct line
      _createDirectPolyline();
    }
  }

  void _createDirectPolyline() {
    if (_selectedRequest == null ||
        _driverLatitude == null ||
        _driverLongitude == null) {
      return;
    }

    final String polylineIdVal = 'polyline_${_selectedRequest!.id}';
    final PolylineId polylineId = PolylineId(polylineIdVal);

    // Create a direct line between the two points as fallback
    final Polyline polyline = Polyline(
      polylineId: polylineId,
      color: Colors.red, // Different color to indicate it's a direct line
      width: 5,
      points: [
        LatLng(_driverLatitude!, _driverLongitude!),
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
    if (_mapController == null) return;

    // Create bounds that include all points
    LatLngBounds bounds;

    if (_routeCoordinates.isNotEmpty) {
      bounds = _createBoundsFromList(_routeCoordinates);
    } else {
      // Fallback if we only have start and end points
      bounds = LatLngBounds(
        southwest: LatLng(
          _driverLatitude! < _selectedRequest!.location.latitude
              ? _driverLatitude!
              : _selectedRequest!.location.latitude,
          _driverLongitude! < _selectedRequest!.location.longitude
              ? _driverLongitude!
              : _selectedRequest!.location.longitude,
        ),
        northeast: LatLng(
          _driverLatitude! > _selectedRequest!.location.latitude
              ? _driverLatitude!
              : _selectedRequest!.location.latitude,
          _driverLongitude! > _selectedRequest!.location.longitude
              ? _driverLongitude!
              : _selectedRequest!.location.longitude,
        ),
      );
    }

    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
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

    return LatLngBounds(
      northeast: LatLng(x1!, y1!),
      southwest: LatLng(x0!, y0!),
    );
  }

  RequestType _getRequestTypeFromUser(UserModel? user) {
    if (user == null || user.userType == null) {
      print(
          "Warning: User or userType is null, defaulting to mechanic requests.");
      return RequestType.mechanic;
    }
    switch (user.userType.toLowerCase()) {
      case 'sos':
        return RequestType.sos;
      case 'mechanic':
        return RequestType.mechanic;
      default:
        print(
            "Warning: Unknown userType '${user.userType}', defaulting to mechanic requests.");
        return RequestType.mechanic;
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS Home'),
      ),
      body: _selectedIndex == 0
          ? Column(
              children: [
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'SOS Current Location: $_currentLocationText',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<Request>>(
                    stream: _nearbySosRequestStream,
                    builder: (context, snapshot) {
                      if (_nearbySosRequestStream == null ||
                          snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: _driverLatitude == null
                              ? const Text("Waiting for location...")
                              : const CircularProgressIndicator(),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        // Still show the map even if there are no requests
                        return _buildGoogleMap(const []);
                      }

                      List<Request> sosRequests = snapshot.data!;
                      return _buildGoogleMap(sosRequests);
                    },
                  ),
                ),
              ],
            )
          : ProfileTab(user: widget.user),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.warning),
            label: 'Requests',
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

  Widget _buildGoogleMap(List<Request> requests) {
    if (_driverLatitude == null || _driverLongitude == null) {
      return const Center(child: Text("Waiting for location..."));
    }

    // Update markers whenever requests change
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateMarkers(requests);
    });

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(_driverLatitude!, _driverLongitude!),
            zoom: 14.0,
          ),
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          markers: _markers,
          polylines: Set<Polyline>.of(_polylines.values),
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
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
    _sosLocationService.dispose();
    _routeUpdateTimer?.cancel();
    super.dispose();
  }
}
