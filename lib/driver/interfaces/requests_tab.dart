import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/request_services.dart';
import '../../services/authentication_services.dart';
import '../../models/request_model.dart';

class RequestsTab extends StatefulWidget {
  const RequestsTab({super.key});

  @override
  RequestsTabState createState() => RequestsTabState();
}

class RequestsTabState extends State<RequestsTab> {
  final AuthenticationService _authService = AuthenticationService();
  final RequestService _requestService = RequestService();
  DateTime? _selectedDate;
  bool _sortDescending = false;

  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    User? currentUser =
        await _authService.getCurrentFirebaseUser(); // Updated function name
    if (currentUser != null) {
      setState(() {
        _userId = currentUser.uid;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Stream<List<Request>> _getFilteredRequests() {
    if (_userId == null) {
      return const Stream.empty();
    }

    if (_selectedDate != null) {
      return _requestService.getRequestsByUserIdAndDate(
          _userId!, _selectedDate!);
    } else {
      return _requestService.getRequestsByUserIdSorted(_userId!,
          descending: _sortDescending);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demandes'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () => _selectDate(context),
                child: const Text('Sélectionner une date'),
              ),
              IconButton(
                icon: Icon(_sortDescending
                    ? Icons.arrow_downward
                    : Icons.arrow_upward),
                onPressed: () {
                  setState(() {
                    _sortDescending = !_sortDescending;
                  });
                },
              ),
            ],
          ),
          Expanded(
            child: _userId == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<List<Request>>(
                    stream: _getFilteredRequests(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(
                            child: Text('Aucune demande trouvée.'));
                      }

                      List<Request> requests = snapshot.data!;

                      return ListView.builder(
                        itemCount: requests.length,
                        itemBuilder: (context, index) {
                          Request request = requests[index];
                          return Card(
                            child: ListTile(
                              title: Text('ID de demande: ${request.id}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      'Emplacement: ${request.location.placeName}'),
                                  Text(
                                      'Heure: ${DateFormat('yyyy-MM-dd HH:mm').format(request.time.toDate())}'),
                                  Text(
                                    'Statut: ${_translateStatus(request.status)}',
                                    style: TextStyle(
                                        color: _getStatusColor(request.status)),
                                  ),
                                  Text(
                                      'Type: ${_translateRequestType(request.requestType)}'),
                                  // Show car brand and model for mechanic requests
                                  if (request.requestType ==
                                      RequestType.mechanic) ...[
                                    if (request.carBrand != null &&
                                        request.carBrand!.isNotEmpty)
                                      Text(
                                          'Marque de voiture: ${request.carBrand}'),
                                    if (request.carModel != null &&
                                        request.carModel!.isNotEmpty)
                                      Text(
                                          'Modèle de voiture: ${request.carModel}'),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(RequestStatus status) {
    switch (status) {
      case RequestStatus.pending:
        return Colors.orange;
      case RequestStatus.accepted:
        return Colors.green;
      case RequestStatus.rejected:
        return Colors.red;
      case RequestStatus.completed:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _translateStatus(RequestStatus status) {
    switch (status) {
      case RequestStatus.pending:
        return 'En attente';
      case RequestStatus.accepted:
        return 'Accepté';
      case RequestStatus.rejected:
        return 'Rejeté';
      case RequestStatus.completed:
        return 'Terminé';
      default:
        return status.name;
    }
  }

  String _translateRequestType(RequestType type) {
    switch (type) {
      case RequestType.sos:
        return 'SOS';
      case RequestType.mechanic:
        return 'Mécanicien';
    }
  }
}

@immutable
class ExpandableFab extends StatefulWidget {
  const ExpandableFab({
    super.key,
    this.initialOpen,
    required this.distance,
    required this.children,
  });

  final bool? initialOpen;
  final double distance;
  final List<Widget> children;

  @override
  State<ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<ExpandableFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _open = widget.initialOpen ?? false;
    _controller = AnimationController(
      value: _open ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.easeOutQuad,
      parent: _controller,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _open = !_open;
      if (_open) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        alignment: Alignment.bottomRight,
        clipBehavior: Clip.none,
        children: [
          _buildTapToCloseFab(),
          ..._buildExpandingActionButtons(),
          _buildTapToOpenFab(),
        ],
      ),
    );
  }

  Widget _buildTapToCloseFab() {
    return SizedBox(
      width: 56.0,
      height: 56.0,
      child: Center(
        child: Material(
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          elevation: 4.0,
          child: InkWell(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                Icons.close,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildExpandingActionButtons() {
    final children = <Widget>[];
    final count = widget.children.length;
    final step = 90.0 / (count - 1);
    for (var i = 0, angleInDegrees = 0.0;
        i < count;
        i++, angleInDegrees += step) {
      children.add(
        _ExpandingActionButton(
          directionInDegrees: angleInDegrees,
          maxDistance: widget.distance,
          progress: _expandAnimation,
          child: widget.children[i],
        ),
      );
    }
    return children;
  }

  Widget _buildTapToOpenFab() {
    return IgnorePointer(
      ignoring: _open,
      child: AnimatedContainer(
        transformAlignment: Alignment.center,
        transform: Matrix4.diagonal3Values(
          _open ? 0.7 : 1.0,
          _open ? 0.7 : 1.0,
          1.0,
        ),
        duration: const Duration(milliseconds: 250),
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
        child: AnimatedOpacity(
          opacity: _open ? 0.0 : 1.0,
          curve: const Interval(0.25, 1.0, curve: Curves.easeInOut),
          duration: const Duration(milliseconds: 250),
          child: FloatingActionButton(
            onPressed: _toggle,
            child: const Icon(Icons.create),
          ),
        ),
      ),
    );
  }
}

@immutable
class _ExpandingActionButton extends StatelessWidget {
  const _ExpandingActionButton({
    required this.directionInDegrees,
    required this.maxDistance,
    required this.progress,
    required this.child,
  });

  final double directionInDegrees;
  final double maxDistance;
  final Animation<double> progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, child) {
        final offset = Offset.fromDirection(
          directionInDegrees * (pi / 180.0),
          progress.value * maxDistance,
        );
        return Positioned(
          right: 4.0 + offset.dx,
          bottom: 4.0 + offset.dy,
          child: Transform.rotate(
            angle: (1.0 - progress.value) * pi / 2,
            child: child!,
          ),
        );
      },
      child: FadeTransition(
        opacity: progress,
        child: child,
      ),
    );
  }
}

@immutable
class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    this.onPressed,
    required this.icon,
  });

  final VoidCallback? onPressed;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.secondary,
      elevation: 4.0,
      child: IconButton(
        onPressed: onPressed,
        icon: icon,
        color: theme.colorScheme.onSecondary,
      ),
    );
  }
}
