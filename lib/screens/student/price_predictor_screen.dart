import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/hostel_model.dart';
import '../../services/ml_price_service.dart';

class PricePredictorScreen extends StatefulWidget {
  const PricePredictorScreen({super.key});

  @override
  State<PricePredictorScreen> createState() => _PricePredictorScreenState();
}

class _PricePredictorScreenState extends State<PricePredictorScreen> {
  // Input fields for predictor
  double _distance = 1.5; // in km
  double _rating = 4.0;
  String _hostelType = "Co-Ed";
  
  final Set<String> _selectedFacilities = {"WiFi", "Food"};
  final List<String> _availableFacilities = [
    "WiFi", "Food", "AC", "Laundry", "Gym", "Single Room", "CCTV", "Power Backup", "Geyser"
  ];

  double _predictedPrice = 0.0;
  bool _isTraining = true;
  int _hostelsCount = 0;

  @override
  void initState() {
    super.initState();
    _trainLocalModel();
  }

  Future<void> _trainLocalModel() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('hostels').get();
      final hostels = snap.docs.map((doc) => HostelModel.fromMap(doc.data(), doc.id)).toList();
      
      // Train model on live list of hostels
      MLPriceService().trainModel(hostels);
      
      setState(() {
        _hostelsCount = hostels.length;
        _isTraining = false;
      });
      _updatePrediction();
    } catch (e) {
      setState(() {
        _isTraining = false;
      });
      _updatePrediction();
    }
  }

  void _updatePrediction() {
    final price = MLPriceService().predictPrice(
      distanceFromCollege: _distance,
      hostelType: _hostelType,
      rating: _rating,
      facilitiesCount: _selectedFacilities.length,
    );
    setState(() {
      _predictedPrice = price;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("ML Rent Predictor"),
        centerTitle: true,
      ),
      body: _isTraining
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Training ML Model on live data...", style: TextStyle(color: Colors.black54)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Prediction Display Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E3C72).withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.analytics_outlined, color: Colors.white, size: 40),
                        const SizedBox(height: 12),
                        const Text(
                          "Estimated Rent Prediction",
                          style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "₹${_predictedPrice.toInt()}/month",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "Trained on $_hostelsCount Local Hostels",
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),

                  // Inputs Section
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Customize Hostel Features",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Divider(height: 25),

                          // Distance Input
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Distance from College", style: TextStyle(fontWeight: FontWeight.w500)),
                              Text("${_distance.toStringAsFixed(1)} km", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Slider(
                            value: _distance,
                            min: 0.1,
                            max: 10.0,
                            divisions: 99,
                            activeColor: Colors.blue,
                            inactiveColor: Colors.blue.shade100,
                            onChanged: (val) {
                              setState(() => _distance = val);
                              _updatePrediction();
                            },
                          ),
                          const SizedBox(height: 15),

                          // Rating Input
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Target Rating (User Reviews)", style: TextStyle(fontWeight: FontWeight.w500)),
                              Text("${_rating.toStringAsFixed(1)} ★", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Slider(
                            value: _rating,
                            min: 1.0,
                            max: 5.0,
                            divisions: 40,
                            activeColor: Colors.amber,
                            inactiveColor: Colors.amber.shade100,
                            onChanged: (val) {
                              setState(() => _rating = val);
                              _updatePrediction();
                            },
                          ),
                          const SizedBox(height: 20),

                          // Hostel Type Selection
                          const Text("Hostel Category", style: TextStyle(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 10),
                          Row(
                            children: ["Boys", "Girls", "Co-Ed"].map((type) {
                              bool isSelected = _hostelType == type;
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                  child: ChoiceChip(
                                    label: Text(type),
                                    selected: isSelected,
                                    selectedColor: Colors.blue.shade600,
                                    disabledColor: Colors.transparent,
                                    labelStyle: TextStyle(
                                      color: isSelected ? Colors.white : Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() => _hostelType = type);
                                        _updatePrediction();
                                      }
                                    },
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Facilities Section
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Select Amenities",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            "Adding more amenities increases the predicted rental price.",
                            style: TextStyle(color: Colors.black54, fontSize: 13),
                          ),
                          const Divider(height: 25),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availableFacilities.map((facility) {
                              final isSelected = _selectedFacilities.contains(facility);
                              return FilterChip(
                                label: Text(facility),
                                selected: isSelected,
                                onSelected: (checked) {
                                  setState(() {
                                    if (checked) {
                                      _selectedFacilities.add(facility);
                                    } else {
                                      _selectedFacilities.remove(facility);
                                    }
                                  });
                                  _updatePrediction();
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}
