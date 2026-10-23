import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class _HostelData {
  final double distanceFromCollege;
  final String hostelType;
  final double rating;
  final List<String> facilities;
  final int price;

  _HostelData({
    required this.distanceFromCollege,
    required this.hostelType,
    required this.rating,
    required this.facilities,
    required this.price,
  });

  factory _HostelData.fromMap(Map<String, dynamic> map) {
    return _HostelData(
      distanceFromCollege: (map['distanceFromCollege'] as num?)?.toDouble() ?? 1.5,
      hostelType: map['hostelType'] ?? 'Co-Ed',
      rating: (map['rating'] as num?)?.toDouble() ?? 4.0,
      facilities: List<String>.from(map['facilities'] ?? []),
      price: (map['price'] as num?)?.toInt() ?? 5000,
    );
  }
}

class _MLPriceService {
  List<double> _weights = [5000.0, -500.0, 300.0, 100.0, 400.0];

  final Map<String, double> _minValues = {
    'distance': 0.0,
    'rating': 1.0,
    'type': -1.0,
    'facilities': 0.0,
  };

  final Map<String, double> _maxValues = {
    'distance': 10.0,
    'rating': 5.0,
    'type': 1.0,
    'facilities': 10.0,
  };

  static final _MLPriceService _instance = _MLPriceService._internal();
  factory _MLPriceService() => _instance;
  _MLPriceService._internal();

  double _normalize(double val, String key) {
    double minV = _minValues[key] ?? 0.0;
    double maxV = _maxValues[key] ?? 1.0;
    if (maxV == minV) return 0.5;
    return (val - minV) / (maxV - minV);
  }

  void trainModel(List<_HostelData> hostels) {
    if (hostels.length < 3) return;

    List<double> distances = hostels.map((h) => h.distanceFromCollege).toList();
    List<double> ratings = hostels.map((h) => h.rating).toList();
    List<double> types = hostels.map((h) => _encodeType(h.hostelType)).toList();
    List<double> facilitiesCounts = hostels.map((h) => h.facilities.length.toDouble()).toList();
    List<double> prices = hostels.map((h) => h.price.toDouble()).toList();

    _minValues['distance'] = distances.reduce(min);
    _maxValues['distance'] = distances.reduce(max);

    _minValues['rating'] = ratings.reduce(min);
    _maxValues['rating'] = ratings.reduce(max);

    _minValues['type'] = types.reduce(min);
    _maxValues['type'] = types.reduce(max);

    _minValues['facilities'] = facilitiesCounts.reduce(min);
    _maxValues['facilities'] = facilitiesCounts.reduce(max);

    List<List<double>> X = [];
    List<double> Y = prices;

    for (int i = 0; i < hostels.length; i++) {
      X.add([
        1.0,
        _normalize(distances[i], 'distance'),
        _normalize(ratings[i], 'rating'),
        _normalize(types[i], 'type'),
        _normalize(facilitiesCounts[i], 'facilities'),
      ]);
    }

    double averagePrice = prices.reduce((a, b) => a + b) / prices.length;
    List<double> weights = [averagePrice, 0.0, 0.0, 0.0, 0.0];

    double alpha = 0.05;
    int epochs = 2000;
    int n = hostels.length;

    for (int epoch = 0; epoch < epochs; epoch++) {
      List<double> gradients = [0.0, 0.0, 0.0, 0.0, 0.0];

      for (int i = 0; i < n; i++) {
        double prediction = 0.0;
        for (int j = 0; j < 5; j++) {
          prediction += weights[j] * X[i][j];
        }
        double error = prediction - Y[i];

        for (int j = 0; j < 5; j++) {
          gradients[j] += error * X[i][j];
        }
      }

      for (int j = 0; j < 5; j++) {
        weights[j] -= (alpha * gradients[j]) / n;
      }
    }

    _weights = weights;
  }

  double predictPrice({
    required double distanceFromCollege,
    required String hostelType,
    required double rating,
    required int facilitiesCount,
  }) {
    double normDist = _normalize(distanceFromCollege, 'distance');
    double normRating = _normalize(rating, 'rating');
    double normType = _normalize(_encodeType(hostelType), 'type');
    double normFac = _normalize(facilitiesCount.toDouble(), 'facilities');

    double prediction = _weights[0] +
        _weights[1] * normDist +
        _weights[2] * normRating +
        _weights[3] * normType +
        _weights[4] * normFac;

    return max(1500.0, prediction);
  }

  double _encodeType(String type) {
    switch (type.toLowerCase()) {
      case 'boys':
        return 1.0;
      case 'girls':
        return -1.0;
      case 'co-ed':
      default:
        return 0.0;
    }
  }
}

class PricePredictorScreen extends StatefulWidget {
  const PricePredictorScreen({super.key});

  @override
  State<PricePredictorScreen> createState() => _PricePredictorScreenState();
}

class _PricePredictorScreenState extends State<PricePredictorScreen> {
  double _distance = 1.5;
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
      final hostels = snap.docs.map((doc) => _HostelData.fromMap(doc.data())).toList();

      _MLPriceService().trainModel(hostels);

      if (mounted) {
        setState(() {
          _hostelsCount = hostels.length;
          _isTraining = false;
        });
        _updatePrediction();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTraining = false;
        });
        _updatePrediction();
      }
    }
  }

  void _updatePrediction() {
    final price = _MLPriceService().predictPrice(
      distanceFromCollege: _distance,
      hostelType: _hostelType,
      rating: _rating,
      facilitiesCount: _selectedFacilities.length,
    );
    if (mounted) {
      setState(() {
        _predictedPrice = price;
      });
    }
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
                          color: const Color(0xFF1E3C72).withValues(alpha: 0.3),
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
