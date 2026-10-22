import 'dart:math';
import '../models/hostel_model.dart';

class MLPriceService {
  // Model weights: 
  // w0 = Intercept, w1 = Distance, w2 = Rating, w3 = Type, w4 = FacilitiesCount
  List<double> _weights = [5000.0, -500.0, 300.0, 100.0, 400.0]; // Default baseline weights
  
  // Scaling factors for normalization
  Map<String, double> _minValues = {
    'distance': 0.0,
    'rating': 1.0,
    'type': -1.0,
    'facilities': 0.0,
  };
  
  Map<String, double> _maxValues = {
    'distance': 10.0,
    'rating': 5.0,
    'type': 1.0,
    'facilities': 10.0,
  };

  static final MLPriceService _instance = MLPriceService._internal();
  factory MLPriceService() => _instance;
  MLPriceService._internal();

  /// Normalizes a value between 0 and 1
  double _normalize(double val, String key) {
    double minV = _minValues[key] ?? 0.0;
    double maxV = _maxValues[key] ?? 1.0;
    if (maxV == minV) return 0.5;
    return (val - minV) / (maxV - minV);
  }

  /// Train the ML model on current database of hostels
  void trainModel(List<HostelModel> hostels) {
    if (hostels.length < 3) {
      // Too few hostels to train a stable model, use fallback weights
      return;
    }

    // 1. Calculate min-max values for normalization
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

    // 2. Prepare normalized training dataset
    List<List<double>> X = []; // Features: [1, norm_dist, norm_rating, norm_type, norm_fac]
    List<double> Y = prices;   // Label: price

    for (int i = 0; i < hostels.length; i++) {
      X.add([
        1.0, // Intercept
        _normalize(distances[i], 'distance'),
        _normalize(ratings[i], 'rating'),
        _normalize(types[i], 'type'),
        _normalize(facilitiesCounts[i], 'facilities'),
      ]);
    }

    // 3. Initialize weights to average price and zeroes
    double averagePrice = prices.reduce((a, b) => a + b) / prices.length;
    List<double> weights = [averagePrice, 0.0, 0.0, 0.0, 0.0];

    // 4. Gradient Descent parameters
    double alpha = 0.05; // Learning rate
    int epochs = 2000;
    int n = hostels.length;

    for (int epoch = 0; epoch < epochs; epoch++) {
      List<double> gradients = [0.0, 0.0, 0.0, 0.0, 0.0];

      // Calculate gradients
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

      // Update weights
      for (int j = 0; j < 5; j++) {
        weights[j] -= (alpha * gradients[j]) / n;
      }
    }

    _weights = weights;
  }

  /// Predict the price of a hostel based on its features
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

    // Ensure predictions remain in a sensible positive range
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
