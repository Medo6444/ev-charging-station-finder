import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:grad02/private/private.dart'; // Your API key file

class LocationSearchBar extends StatefulWidget {
  final Function(LatLng, String) onLocationSelected;  // Remove nullable
  final String selectedValue;
  final List<String> dropDownItems;
  final Function(String) onDropdownChanged;  // Remove nullable
  final Function() onSearchPressed;

  const LocationSearchBar({
    Key? key,
    required this.onLocationSelected,
    required this.selectedValue,
    required this.dropDownItems,
    required this.onDropdownChanged,
    required this.onSearchPressed,
  }) : super(key: key);

  @override
  State<LocationSearchBar> createState() => _LocationSearchBarState();
}

class _LocationSearchBarState extends State<LocationSearchBar> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<PlacePrediction> _predictions = [];
  bool _isLoading = false;
  bool _showPredictions = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_searchFocusNode.hasFocus) {
      // Hide predictions when search bar loses focus (with a small delay)
      Future.delayed(Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            _showPredictions = false;
          });
        }
      });
    }
  }

  void _onSearchChanged() {
    // Remove: if (!widget.isEnabled) return;

    final query = _searchController.text;
    if (query.length > 2) {
      _searchPlaces(query);
    } else {
      setState(() {
        _predictions.clear();
        _showPredictions = false;
      });
    }
  }

  Future<void> _searchPlaces(String query) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/place/autocomplete/json'
              '?input=$query'
              '&key=$googleApiKey'
              '&types=geocode'
              '&components=country:eg', // Restrict to Egypt, change as needed
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final List<PlacePrediction> predictions = (data['predictions'] as List)
              .map((pred) => PlacePrediction.fromJson(pred))
              .toList();

          setState(() {
            _predictions = predictions;
            _showPredictions = predictions.isNotEmpty;
            _isLoading = false;
          });
        } else {
          print('Places API error: ${data['status']}');
          setState(() {
            _predictions.clear();
            _showPredictions = false;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error searching places: $e');
      setState(() {
        _predictions.clear();
        _showPredictions = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectPlace(PlacePrediction prediction) async {
    setState(() {
      _searchController.text = prediction.description;
      _showPredictions = false;
      _isLoading = true;
    });

    _searchFocusNode.unfocus();

    try {
      // Get place details to get coordinates
      final response = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/place/details/json'
              '?place_id=${prediction.placeId}'
              '&key=$googleApiKey'
              '&fields=geometry',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final location = data['result']['geometry']['location'];
          final latLng = LatLng(location['lat'], location['lng']);

          // Callback to parent widget
          widget.onLocationSelected.call(latLng, prediction.description);  // Use null-aware call
        }
      }
    } catch (e) {
      print('Error getting place details: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _predictions.clear();
      _showPredictions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Main search and dropdown row
        Row(
          children: [
            // Dropdown menu
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              width: 120,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,  // Remove conditional styling
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: widget.selectedValue,
                  hint: Text('Battery'),
                  isExpanded: true,
                  onChanged: (String? newValue) {  // Remove conditional logic
                    if (newValue != null) {
                      widget.onDropdownChanged(newValue);  // Remove null-aware call
                    }
                  },
                  items: widget.dropDownItems.map<DropdownMenuItem<String>>(
                        (String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: TextStyle(color: Colors.black, fontSize: 12),  // Remove conditional styling
                        ),
                      );
                    },
                  ).toList(),
                ),
              ),
            ),

            // Search bar
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,  // Remove conditional styling
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  // Remove: enabled: widget.isEnabled,
                  decoration: InputDecoration(
                    hintText: 'Search for a location...',  // Remove conditional text
                    hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),  // Remove conditional styling
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    suffixIcon: _searchController.text.isNotEmpty  // Remove isEnabled check
                        ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey.shade600),
                      onPressed: _clearSearch,
                      splashRadius: 20,
                    )
                        : _isLoading  // Remove isEnabled check
                        ? Container(
                      width: 20,
                      height: 20,
                      margin: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.greenAccent.shade700,
                        ),
                      ),
                    )
                        : Icon(Icons.search, color: Colors.grey.shade600),
                  ),
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),


            // Search button
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.greenAccent.shade700,  // Remove conditional styling
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
                border: Border.all(color: Colors.greenAccent.shade700, width: 1),
              ),
              child: IconButton(
                icon: Icon(Icons.search, color: Colors.black),  // Remove conditional styling
                onPressed: widget.onSearchPressed,  // Remove conditional logic
                splashRadius: 20,
              ),
            ),
          ],
        ),

        // Predictions dropdown
        if (_showPredictions && _predictions.isNotEmpty)
          Container(
            margin: EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            constraints: BoxConstraints(
              maxHeight: 200,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _predictions.length,
              itemBuilder: (context, index) {
                final prediction = _predictions[index];
                return InkWell(
                  onTap: () => _selectPlace(prediction),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: index < _predictions.length - 1
                          ? Border(bottom: BorderSide(color: Colors.grey.shade200))
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: Colors.grey.shade600,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                prediction.mainText,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              if (prediction.secondaryText.isNotEmpty)
                                Text(
                                  prediction.secondaryText,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    return PlacePrediction(
      placeId: json['place_id'] ?? '',
      description: json['description'] ?? '',
      mainText: json['structured_formatting']?['main_text'] ?? '',
      secondaryText: json['structured_formatting']?['secondary_text'] ?? '',
    );
  }
}