import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LocationPicker extends StatefulWidget {
  final Function(double lat, double lng, String address) onLocationSelected;
  final LatLng? initialLocation;
  final String? initialAddress;
  
  const LocationPicker({
    super.key, 
    required this.onLocationSelected,
    this.initialLocation,
    this.initialAddress,
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> with SingleTickerProviderStateMixin {
  late LatLng _currentLocation;
  late MapController _mapController;
  String _currentAddress = '';
  String _searchQuery = '';
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  bool _isLoadingLocation = false;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentLocation = widget.initialLocation ?? const LatLng(28.6139, 77.2090); // India center
    _currentAddress = widget.initialAddress ?? '';
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _searchLocation() async {
    if (_searchQuery.isEmpty) return;
    
    setState(() => _isSearching = true);
    
    try {
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(_searchQuery)}&format=json&limit=5&addressdetails=1'),
        headers: {'User-Agent': 'EKirayaApp/1.0'},
      );
      
      if (response.statusCode == 200) {
        setState(() {
          _searchResults = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _selectLocation(dynamic result) {
    final lat = double.parse(result['lat']);
    final lon = double.parse(result['lon']);
    final displayName = result['display_name'];
    
    setState(() {
      _currentLocation = LatLng(lat, lon);
      _currentAddress = displayName;
      _searchResults = [];
      _searchController.clear();
      _searchQuery = '';
    });
    
    _mapController.move(_currentLocation, 16);
    widget.onLocationSelected(lat, lon, displayName);
    
    // Show success feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Location selected'),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    
    // Note: For actual GPS, you'd need geolocator package
    await Future.delayed(const Duration(milliseconds: 500));
    
    _mapController.move(_currentLocation, 16);
    
    setState(() => _isLoadingLocation = false);
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json&addressdetails=1'),
        headers: {'User-Agent': 'EKirayaApp/1.0'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['display_name'] ?? '';
        setState(() {
          _currentAddress = address;
        });
        widget.onLocationSelected(lat, lng, address);
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        _searchQuery = value;
                        _searchLocation();
                      },
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade900),
                      decoration: InputDecoration(
                        hintText: 'Search for a location...',
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                        prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade500),
                        suffixIcon: _isSearching 
                            ? Padding(
                                padding: const EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              )
                            : _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear, size: 18, color: Colors.grey.shade500),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                        _searchResults = [];
                                      });
                                    },
                                  )
                                : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: IconButton(
                    icon: _isLoadingLocation
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.grey.shade700,
                            ),
                          )
                        : Icon(Icons.my_location, size: 18, color: Colors.grey.shade700),
                    onPressed: _getCurrentLocation,
                    tooltip: 'Use current location',
                  ),
                ),
              ],
            ),
          ),
          
          // Search Results Dropdown
          AnimatedCrossFade(
            firstChild: const SizedBox(height: 0),
            secondChild: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.3,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  return Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade50),
                      ),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.grey.shade100,
                        child: Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                      ),
                      title: Text(
                        result['display_name'],
                        style: const TextStyle(fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
                      onTap: () => _selectLocation(result),
                    ),
                  );
                },
              ),
            ),
            crossFadeState: _searchResults.isEmpty ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
          ),
          
          // Address Info Bar
          if (_currentAddress.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_pin, size: 16, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentAddress,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Selected',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.green.shade700),
                    ),
                  ),
                ],
              ),
            ),
          
          // Map
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentLocation,
                  initialZoom: 14,
                  minZoom: 3,
                  maxZoom: 19,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                  onTap: (tapPosition, point) {
                    setState(() {
                      _currentLocation = point;
                    });
                    _reverseGeocode(point.latitude, point.longitude);
                  },
                ),
                children: [
                  // Light-themed tile layer
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.ekiraya.app',
                    tileProvider: NetworkTileProvider(),
                  ),
                  
                  // Current location marker with animation
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentLocation,
                        width: 50,
                        height: 50,
                        alignment: Alignment.center,
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                // Pulsing circle effect
                                Container(
                                  width: 30 + (15 * _pulseAnimation.value),
                                  height: 30 + (15 * _pulseAnimation.value),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.red.withOpacity(0.3 * (1 - _pulseAnimation.value)),
                                  ),
                                ),
                                // Main pin
                                const Icon(
                                  Icons.location_pin,
                                  color: Colors.red,
                                  size: 42,
                                ),
                                // Center dot
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  // Attribution layer (required for OSM) - Fixed alignment
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        'OpenStreetMap contributors',
                        onTap: () {
                          // Optional: Open OSM attribution URL
                          debugPrint('OSM attribution tapped');
                        },
                      ),
                    ],
                    alignment: AttributionAlignment.bottomRight,
                    popupInitialDisplayDuration: const Duration(seconds: 0),
                  ),
                ],
              ),
            ),
          ),
          
          // Bottom Hint
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              border: Border(top: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.touch_app, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Text(
                  'Tap on map to select location',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}