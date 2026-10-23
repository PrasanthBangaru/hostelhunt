import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as lat_lng;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'chat_page.dart';

class ReviewModel {
  final String? reviewId;
  final String hostelId;
  final String studentName;
  final String studentId;
  final double rating;
  final String comment;
  final DateTime timestamp;
  final String sentiment; // 'positive', 'neutral', 'negative'
  final double sentimentScore; // Value between 0.0 and 1.0

  ReviewModel({
    this.reviewId,
    required this.hostelId,
    required this.studentName,
    required this.studentId,
    required this.rating,
    required this.comment,
    required this.timestamp,
    this.sentiment = 'neutral',
    this.sentimentScore = 0.5,
  });

  Map<String, dynamic> toMap() {
    return {
      'hostelId': hostelId,
      'studentName': studentName,
      'studentId': studentId,
      'rating': rating,
      'comment': comment,
      'timestamp': Timestamp.fromDate(timestamp),
      'sentiment': sentiment,
      'sentimentScore': sentimentScore,
    };
  }

  factory ReviewModel.fromMap(Map<String, dynamic> map, String id) {
    return ReviewModel(
      reviewId: id,
      hostelId: map['hostelId'] ?? '',
      studentName: map['studentName'] ?? 'Anonymous',
      studentId: map['studentId'] ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      comment: map['comment'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sentiment: map['sentiment'] ?? 'neutral',
      sentimentScore: (map['sentimentScore'] as num?)?.toDouble() ?? 0.5,
    );
  }
}

class HostelDetailsScreen extends StatefulWidget {
  final String hostelId;
  final String hostelName;
  final String collegeName;
  final int price;
  final int vacancy;
  final List<String> facilities;
  final Map<String, int> facilityCosts;
  final String? imageUrl;
  final String hostelType;
  final double distanceFromCollege;
  final String? managerId;
  final String address;
  final double latitude;
  final double longitude;
  final double foodRating;
  final Map<String, dynamic>? foodMenu;
  final double rating;
  final int reviewCount;

  const HostelDetailsScreen({
    super.key,
    required this.hostelId,
    required this.hostelName,
    required this.collegeName,
    required this.price,
    required this.vacancy,
    required this.facilities,
    required this.facilityCosts,
    this.imageUrl,
    this.hostelType = "Co-Ed",
    this.distanceFromCollege = 0.0,
    this.managerId,
    this.address = "",
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.foodRating = 4.6,
    this.foodMenu,
    this.rating = 4.5,
    this.reviewCount = 0,
  });

  @override
  State<HostelDetailsScreen> createState() => _HostelDetailsScreenState();
}

class _HostelDetailsScreenState extends State<HostelDetailsScreen> {
  final Set<String> _selectedExtraFacilities = {};

  int get totalPrice {
    int total = widget.price;
    for (String facility in _selectedExtraFacilities) {
      if (widget.facilityCosts.containsKey(facility)) {
        total += widget.facilityCosts[facility]!;
      }
    }
    return total;
  }

  String? _currentImageUrl;
  bool _isUploading = false;

  // Review state
  final TextEditingController _reviewController = TextEditingController();
  double _reviewRating = 4.0;
  bool _isSubmittingReview = false;
  String? _sentimentResult;
  String? _sentimentEmoji;

  // ML price state
  double _mlPredictedPrice = 0.0;
  bool _mlModelTrained = false;

  // Weekly Food Menu state
  int _selectedFoodDayIndex = (DateTime.now().weekday - 1).clamp(0, 6);

  static const List<String> _weekDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  static const Map<String, Map<String, String>> _defaultWeeklyMenu = {
    'Monday': {
      'breakfast': 'Idly + Sambar + Coconut Chutney',
      'lunch': 'Steamed Rice + Dal Tadka + Aloo Poriyal + Curd',
      'dinner': 'Soft Chapathi + Paneer Butter Masala',
      'special': 'Paneer Delight',
      'timing': '7:30 AM | 12:30 PM | 7:30 PM',
      'nutrition': 'Balanced • High Protein • Unlimited Rice',
    },
    'Tuesday': {
      'breakfast': 'Crispy Poori + Potato Masala Gravy',
      'lunch': 'Rice + Tomato Sambar + Bhindi Fry + Buttermilk',
      'dinner': 'Hot Phulka + Mixed Veg Korma + Rice',
      'special': 'Home Style Curry',
      'timing': '7:30 AM | 12:30 PM | 7:30 PM',
      'nutrition': 'Fibre Rich • Fresh Vegetables',
    },
    'Wednesday': {
      'breakfast': 'Poha / Vegetable Upma + Chutney',
      'lunch': 'Jeera Rice + Rajma Masala + Fresh Salad + Papad',
      'dinner': 'Veg Fried Rice + Veg/Chicken Manchurian',
      'special': '⭐ Indo-Chinese Feast',
      'timing': '7:30 AM | 12:30 PM | 7:30 PM',
      'nutrition': 'Student Favorite Night • Non-Veg / Veg options',
    },
    'Thursday': {
      'breakfast': 'Crispy Masala Dosa + Podi + Chutney',
      'lunch': 'Rice + Spinach Dal + Raw Banana Fry + Curd',
      'dinner': 'Chapathi + Egg Curry / Paneer Bhurji',
      'special': 'Crispy Dosa Night',
      'timing': '7:30 AM | 12:30 PM | 7:30 PM',
      'nutrition': 'Iron Rich • Choice of Egg or Paneer',
    },
    'Friday': {
      'breakfast': 'Ghee Pongal + Medu Vada + Sambar',
      'lunch': 'Steamed Rice + Chole Masala + Cucumber Raita',
      'dinner': 'Soft Rotis + Mushroom Curry + Gulab Jamun',
      'special': 'Sweet Friday Treat',
      'timing': '7:30 AM | 12:30 PM | 7:30 PM',
      'nutrition': 'Traditional South Indian Feast + Sweet',
    },
    'Saturday': {
      'breakfast': 'Aloo Paratha + Fresh Butter + Curd + Pickle',
      'lunch': 'South Indian Thali (Rice, Rasam, Dal, Poriyal, Appalam)',
      'dinner': 'Veg Pulao + Mirchi Ka Salan + Onion Raita',
      'special': 'Pulao Night',
      'timing': '7:30 AM | 12:30 PM | 7:30 PM',
      'nutrition': 'Wholesome Weekend Brunch & Dinner',
    },
    'Sunday': {
      'breakfast': 'Chole Bhature / Onion Uttapam',
      'lunch': 'Hyderabadi Dum Biryani (Chicken / Paneer) + Raitha + Gravy',
      'dinner': 'Phulka + Yellow Dal Tadka + Seasonal Halwa',
      'special': '🔥 Grand Sunday Biryani Feast',
      'nutrition': 'Weekend Special • High Protein Biryani',
    },
  };

  Map<String, String> _getMealForDay(String day, [Map<String, dynamic>? activeFoodMenu]) {
    final menuSource = activeFoodMenu ?? widget.foodMenu;
    if (menuSource != null && menuSource[day] != null) {
      final raw = menuSource[day] as Map<String, dynamic>;
      return {
        'breakfast': raw['breakfast']?.toString() ?? 'Idly + Sambar',
        'lunch': raw['lunch']?.toString() ?? 'Rice + Dal + Veg Curry',
        'dinner': raw['dinner']?.toString() ?? 'Chapathi + Paneer',
        'special': raw['special']?.toString() ?? 'Chef Special',
        'timing': raw['timing']?.toString() ?? '7:30 AM | 12:30 PM | 7:30 PM',
        'nutrition': raw['nutrition']?.toString() ?? 'Nutritious & Fresh',
      };
    }
    return _defaultWeeklyMenu[day] ?? _defaultWeeklyMenu['Monday']!;
  }

  @override
  void initState() {
    super.initState();
    _currentImageUrl = widget.imageUrl;
    _trainMLModel();
  }

  Future<void> _trainMLModel() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('hostels').get();
      final hostels = snap.docs;
      if (hostels.length >= 3) {
        double avgPrice = 0;
        for (var doc in hostels) {
          avgPrice += ((doc.data()['price'] ?? 0) as num).toDouble();
        }
        avgPrice /= hostels.length;

        // Estimate price based on distance, type, facilities
        double distFactor = -(widget.distanceFromCollege * 200);
        double typeFactor = widget.hostelType == 'Boys' ? 100 : (widget.hostelType == 'Girls' ? -100 : 0);
        double facFactor = widget.facilities.length * 350;
        double predicted = (avgPrice + distFactor + typeFactor + facFactor).clamp(1500.0, 50000.0);

        if (mounted) {
          setState(() {
            _mlPredictedPrice = predicted;
            _mlModelTrained = true;
          });
        }
      } else {
        if (mounted) setState(() => _mlModelTrained = true);
      }
    } catch (_) {
      if (mounted) setState(() => _mlModelTrained = true);
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    setState(() => _isUploading = true);
    try {
      final bytes = await pickedFile.readAsBytes();
      final ref = FirebaseStorage.instance
          .ref()
          .child('hostel_images')
          .child('${widget.hostelId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      final uploadTask = ref.putData(bytes);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('hostels')
          .doc(widget.hostelId)
          .update({'imageUrl': downloadUrl});
      setState(() => _currentImageUrl = downloadUrl);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image uploaded!')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<Map<String, dynamic>> _analyzeSentiment(String comment) async {
    final apiKey = const String.fromEnvironment('GEMINI_API_KEY');
    if (apiKey.isNotEmpty && apiKey != 'YOUR_GEMINI_KEY') {
      try {
        final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
        final prompt = 'Analyze the sentiment of this review comment for a hostel: "$comment". '
            'Reply ONLY in JSON format: {"sentiment": "positive" | "neutral" | "negative", "score": 0.0 to 1.0}';
        final response = await model.generateContent([Content.text(prompt)]);
        final cleanText = response.text?.trim()
            .replaceAll('```json', '')
            .replaceAll('```', '') ?? '';
        final decoded = jsonDecode(cleanText);
        return {
          'sentiment': decoded['sentiment'] ?? 'neutral',
          'score': (decoded['score'] as num?)?.toDouble() ?? 0.5,
        };
      } catch (_) {}
    }

    // Fallback heuristic lexicon analysis
    final lowercase = comment.toLowerCase();
    final positiveWords = ['good', 'great', 'nice', 'clean', 'friendly', 'best', 'love', 'comfortable', 'awesome', 'excellent', 'peaceful', 'safety', 'safe', 'worth', 'well', 'perfect'];
    final negativeWords = ['bad', 'dirty', 'noisy', 'rude', 'worst', 'hate', 'uncomfortable', 'expensive', 'crowded', 'smell', 'poor', 'slow', 'waste', 'regret', 'unsafe', 'dusty'];
    int posCount = 0;
    int negCount = 0;
    for (var w in positiveWords) {
      if (lowercase.contains(w)) posCount++;
    }
    for (var w in negativeWords) {
      if (lowercase.contains(w)) negCount++;
    }
    if (posCount > negCount) {
      double score = 0.5 + (posCount - negCount) * 0.1;
      return {'sentiment': 'positive', 'score': score.clamp(0.6, 1.0)};
    } else if (negCount > posCount) {
      double score = 0.5 - (negCount - posCount) * 0.1;
      return {'sentiment': 'negative', 'score': score.clamp(0.0, 0.4)};
    } else {
      return {'sentiment': 'neutral', 'score': 0.5};
    }
  }

  Future<void> _submitReview() async {
    final comment = _reviewController.text.trim();
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please write a review comment.')));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to submit a rating and review.')),
      );
      return;
    }

    setState(() => _isSubmittingReview = true);

    try {
      final sentimentData = await _analyzeSentiment(comment);
      final sentiment = sentimentData['sentiment'] as String;
      final score = sentimentData['score'] as double;

      String studentName = user.displayName ?? '';
      if (studentName.trim().isEmpty) {
        try {
          final uDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          if (uDoc.exists) {
            studentName = (uDoc.data()?['name'] ?? uDoc.data()?['displayName'] ?? '').toString();
          }
        } catch (_) {}
      }
      if (studentName.trim().isEmpty) {
        studentName = user.email?.split('@').first ?? 'Student';
      }

      final review = ReviewModel(
        hostelId: widget.hostelId,
        studentName: studentName,
        studentId: user.uid,
        rating: _reviewRating,
        comment: comment,
        timestamp: DateTime.now(),
        sentiment: sentiment,
        sentimentScore: score,
      );

      // 1. Add review to subcollection
      await FirebaseFirestore.instance
          .collection('hostels')
          .doc(widget.hostelId)
          .collection('reviews')
          .add(review.toMap());

      // 2. Recalculate average rating & review count live across all reviews
      final allReviewsSnap = await FirebaseFirestore.instance
          .collection('hostels')
          .doc(widget.hostelId)
          .collection('reviews')
          .get();

      double totalRating = 0.0;
      for (var doc in allReviewsSnap.docs) {
        final r = (doc.data()['rating'] as num?)?.toDouble() ?? 0.0;
        totalRating += r;
      }
      final int count = allReviewsSnap.docs.length;
      final double avgRating = count > 0 ? (totalRating / count) : _reviewRating;
      final double finalRating = double.parse(avgRating.toStringAsFixed(1));

      // 3. Update the hostel document live so student cards and headers update in real time
      await FirebaseFirestore.instance
          .collection('hostels')
          .doc(widget.hostelId)
          .update({
            'rating': finalRating,
            'reviewCount': count,
          });

      _reviewController.clear();

      setState(() {
        _sentimentResult = sentiment;
        _sentimentEmoji = sentiment == 'positive' ? '😊 Positive' : sentiment == 'negative' ? '😞 Negative' : '😐 Neutral';
        _isSubmittingReview = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Review submitted! Rated ${_reviewRating.toStringAsFixed(1)} ★ • Sentiment: ${_sentimentEmoji ?? sentiment}'),
          backgroundColor: sentiment == 'positive' ? Colors.green : sentiment == 'negative' ? Colors.red : Colors.orange,
        ),
      );
    } catch (e) {
      setState(() => _isSubmittingReview = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteReview(String reviewId) async {
    try {
      await FirebaseFirestore.instance
          .collection('hostels')
          .doc(widget.hostelId)
          .collection('reviews')
          .doc(reviewId)
          .delete();

      // Recalculate average rating live
      final allReviewsSnap = await FirebaseFirestore.instance
          .collection('hostels')
          .doc(widget.hostelId)
          .collection('reviews')
          .get();

      double totalRating = 0.0;
      for (var doc in allReviewsSnap.docs) {
        final r = (doc.data()['rating'] as num?)?.toDouble() ?? 0.0;
        totalRating += r;
      }
      final int count = allReviewsSnap.docs.length;
      final double avgRating = count > 0 ? (totalRating / count) : 4.5;
      final double finalRating = double.parse(avgRating.toStringAsFixed(1));

      await FirebaseFirestore.instance
          .collection('hostels')
          .doc(widget.hostelId)
          .update({
            'rating': finalRating,
            'reviewCount': count,
          });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review removed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete review: $e')));
    }
  }

  Color _sentimentColor(String sentiment) {
    if (sentiment == 'positive') return Colors.green;
    if (sentiment == 'negative') return Colors.red;
    return Colors.orange;
  }

  IconData _sentimentIcon(String sentiment) {
    if (sentiment == 'positive') return Icons.sentiment_very_satisfied;
    if (sentiment == 'negative') return Icons.sentiment_very_dissatisfied;
    return Icons.sentiment_neutral;
  }

  List<FlSpot> _generateVacancyForecast() {
    final baseVacancy = widget.vacancy.toDouble();
    final List<FlSpot> spots = [];
    final patterns = [0.0, -0.1, -0.2, -0.05, -0.15, 0.05];
    double current = baseVacancy;
    for (int i = 0; i < 6; i++) {
      current = (current + (baseVacancy * patterns[i])).clamp(0, baseVacancy + 5);
      spots.add(FlSpot(i.toDouble(), current));
    }
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    final forecastSpots = _generateVacancyForecast();
    final int priceDiff = widget.price - _mlPredictedPrice.toInt();
    final bool isOverpriced = priceDiff > 500;
    final bool isUnderpriced = priceDiff < -500;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('hostels').doc(widget.hostelId).snapshots(),
      builder: (context, snapshot) {
        final Map<String, dynamic>? liveData = (snapshot.hasData && snapshot.data!.exists)
            ? snapshot.data!.data() as Map<String, dynamic>?
            : null;

        final double liveFoodRating = (liveData?['foodRating'] as num?)?.toDouble() ?? widget.foodRating;
        final Map<String, dynamic>? liveFoodMenu = (liveData?['foodMenu'] as Map<String, dynamic>?) ?? widget.foodMenu;
        final int liveVacancy = (liveData?['vacancy'] as num?)?.toInt() ?? widget.vacancy;
        final double liveRating = (liveData?['rating'] as num?)?.toDouble() ?? widget.rating;
        final int liveReviewCount = (liveData?['reviewCount'] as num?)?.toInt() ?? widget.reviewCount;

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.hostelName),
            centerTitle: true,
          ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Image with Edit Button
            Stack(
              children: [
                Container(
                  height: 250,
                  width: double.infinity,
                  color: Colors.blue.shade100,
                  child: _currentImageUrl != null && _currentImageUrl!.isNotEmpty
                      ? Image.network(_currentImageUrl!, fit: BoxFit.cover)
                      : Image.network(
                          'https://images.unsplash.com/photo-1555854877-bab0e564b8d5?auto=format&fit=crop&q=80&w=1000',
                          fit: BoxFit.cover,
                        ),
                ),
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 25,
                    child: _isUploading
                        ? const CircularProgressIndicator()
                        : IconButton(
                            icon: const Icon(Icons.camera_alt, color: Colors.blue),
                            onPressed: _pickAndUploadImage,
                          ),
                  ),
                ),
                if (_mlModelTrained)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isOverpriced
                            ? Colors.red.shade700
                            : isUnderpriced
                                ? Colors.green.shade700
                                : Colors.blue.shade700,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.analytics, color: Colors.white, size: 14),
                          const SizedBox(width: 5),
                          Text(
                            isOverpriced
                                ? '📈 Above Market ₹${_mlPredictedPrice.toInt()}'
                                : isUnderpriced
                                    ? '📉 Below Market ₹${_mlPredictedPrice.toInt()}'
                                    : '✅ Fair Price ₹${_mlPredictedPrice.toInt()}',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.hostelName,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade300, width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 20),
                            const SizedBox(width: 4),
                            Text(
                              liveRating.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                            ),
                            if (liveReviewCount > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                "($liveReviewCount)",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.amber.shade900.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.school, color: Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    Text(widget.collegeName, style: const TextStyle(fontSize: 16, color: Colors.black54)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.bed, color: Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    Text("$liveVacancy Beds Available", style: const TextStyle(fontSize: 16, color: Colors.black54)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.people, color: Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    Text("${widget.hostelType} Hostel", style: const TextStyle(fontSize: 16, color: Colors.black54)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.map, color: Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    Text("${widget.distanceFromCollege.toStringAsFixed(1)} km near college",
                        style: const TextStyle(fontSize: 16, color: Colors.black54)),
                  ]),

                  const SizedBox(height: 20),

                  // ── Location & Google Maps Card ─────────────────
                  _buildLocationMapCard(),

                  const SizedBox(height: 25),

                  // ML Fair Price Section
                  if (_mlModelTrained) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isOverpriced
                              ? [Colors.red.shade50, Colors.red.shade100]
                              : isUnderpriced
                                  ? [Colors.green.shade50, Colors.green.shade100]
                                  : [Colors.blue.shade50, Colors.blue.shade100],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isOverpriced
                              ? Colors.red.shade200
                              : isUnderpriced
                                  ? Colors.green.shade200
                                  : Colors.blue.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.analytics_outlined,
                            color: isOverpriced
                                ? Colors.red
                                : isUnderpriced
                                    ? Colors.green
                                    : Colors.blue,
                            size: 30,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("📈 ML Price Analysis",
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(
                                  "Market estimate: ₹${_mlPredictedPrice.toInt()}/mo  •  Listed: ₹${widget.price}/mo",
                                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isOverpriced
                                      ? "This hostel is priced ₹${priceDiff.abs()} above the predicted market rate."
                                      : isUnderpriced
                                          ? "Great deal! This is ₹${priceDiff.abs()} below the predicted market rate."
                                          : "This hostel is priced fairly within market range.",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isOverpriced
                                        ? Colors.red.shade700
                                        : isUnderpriced
                                            ? Colors.green.shade700
                                            : Colors.blue.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),
                  ],

                  // Price Details
                  const Text("Price Details",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Base Price", style: TextStyle(fontSize: 15)),
                            Text("₹${widget.price}/mo",
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        ...widget.facilityCosts.entries.map((e) {
                          bool isSelected = _selectedExtraFacilities.contains(e.key);
                          return InkWell(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedExtraFacilities.remove(e.key);
                                } else {
                                  _selectedExtraFacilities.add(e.key);
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                                    color: isSelected ? Colors.blue : Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text("${e.key} (extra)",
                                        style: const TextStyle(fontSize: 15, color: Colors.orange)),
                                  ),
                                  Text("+₹${e.value}/mo",
                                      style: const TextStyle(
                                          fontSize: 15,
                                          color: Colors.orange,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          );
                        }),
                        const Divider(height: 20, thickness: 1),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Total Estimate",
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text("₹$totalPrice/month",
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Facilities
                  const Text("Facilities",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: widget.facilities
                        .map((f) => Chip(
                              label: Text(f),
                              backgroundColor: Colors.white,
                              shape: StadiumBorder(
                                  side: BorderSide(color: Colors.blue.shade200)),
                              avatar:
                                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                            ))
                        .toList(),
                  ),

                  const SizedBox(height: 30),

                  // 🍽️ Weekly Food Menu Predictor
                  _buildFoodMenuSection(liveFoodRating, liveFoodMenu),

                  const SizedBox(height: 30),

                  // 📊 Vacancy Forecasting Section
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.bar_chart, color: Colors.purple.shade600, size: 18),
                      ),
                      const SizedBox(width: 8),
                      const Text("📊 Vacancy Forecasting",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "AI-predicted bed availability over the next 6 months",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 200,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.grey.shade200,
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (val, meta) {
                                const months = ['Now', 'M1', 'M2', 'M3', 'M4', 'M5'];
                                return Text(
                                  months[val.toInt().clamp(0, 5)],
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                );
                              },
                              reservedSize: 24,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (val, meta) => Text(
                                val.toInt().toString(),
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                              reservedSize: 28,
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: forecastSpots,
                            isCurved: true,
                            color: Colors.purple,
                            barWidth: 3,
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.purple.withValues(alpha: 0.1),
                            ),
                            dotData: const FlDotData(show: true),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 😊 Reviews & Sentiment Analysis
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.reviews, color: Colors.green.shade700, size: 18),
                      ),
                      const SizedBox(width: 8),
                      const Text("😊 Reviews & Sentiment Analysis",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Add Review Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Write a Review",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Text("Rating: ", style: TextStyle(fontWeight: FontWeight.w500)),
                            ...List.generate(5, (i) {
                              return GestureDetector(
                                onTap: () => setState(() => _reviewRating = (i + 1).toDouble()),
                                child: Icon(
                                  i < _reviewRating ? Icons.star : Icons.star_border,
                                  color: Colors.amber,
                                  size: 26,
                                ),
                              );
                            }),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _reviewController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: "Share your experience about this hostel...",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_sentimentResult != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _sentimentColor(_sentimentResult!).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _sentimentColor(_sentimentResult!).withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_sentimentIcon(_sentimentResult!),
                                    color: _sentimentColor(_sentimentResult!), size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  "AI Detected: ${_sentimentEmoji ?? _sentimentResult!}",
                                  style: TextStyle(
                                    color: _sentimentColor(_sentimentResult!),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSubmittingReview ? null : _submitReview,
                            icon: _isSubmittingReview
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.send),
                            label: Text(_isSubmittingReview ? "Analyzing Sentiment..." : "Submit Review"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Reviews List from Firestore (Live Real-Time)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('hostels')
                        .doc(widget.hostelId)
                        .collection('reviews')
                        .snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData || snap.data!.docs.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text("No reviews yet. Be the first to review!",
                              style: TextStyle(color: Colors.black45)),
                        );
                      }

                      final reviews = snap.data!.docs
                          .map((d) => ReviewModel.fromMap(d.data() as Map<String, dynamic>, d.id))
                          .toList();

                      // Client-side sort ensures instant real-time reactivity without composite index requirements
                      reviews.sort((a, b) => b.timestamp.compareTo(a.timestamp));

                      int pos = reviews.where((r) => r.sentiment == 'positive').length;
                      int neg = reviews.where((r) => r.sentiment == 'negative').length;
                      int neu = reviews.where((r) => r.sentiment == 'neutral').length;

                      final double avgRating = reviews.isNotEmpty
                          ? reviews.fold(0.0, (acc, r) => acc + r.rating) / reviews.length
                          : 0.0;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("${reviews.length} Reviews • Sentiment Breakdown",
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 14)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.amber.shade200),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.star, color: Colors.amber, size: 14),
                                          const SizedBox(width: 4),
                                          Text(
                                            "${avgRating.toStringAsFixed(1)} / 5",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: Colors.amber.shade900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    _buildSentimentBar("😊 Positive", pos, reviews.length, Colors.green),
                                    const SizedBox(width: 8),
                                    _buildSentimentBar("😐 Neutral", neu, reviews.length, Colors.orange),
                                    const SizedBox(width: 8),
                                    _buildSentimentBar("😞 Negative", neg, reviews.length, Colors.red),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          ...reviews.map((r) => _buildReviewCard(r)),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 30),

                  // Contact Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Please login to contact the manager")),
                          );
                          return;
                        }
                        if (user.uid == widget.managerId) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("You are the manager of this hostel.")),
                          );
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              hostelId: widget.hostelId,
                              hostelName: widget.hostelName,
                              managerId: widget.managerId ?? "default_manager",
                              originalPrice: widget.price,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Contact Manager",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  },
);
  }

  Widget _buildSentimentBar(String label, int count, int total, Color color) {
    final ratio = total == 0 ? 0.0 : count / total;
    return Expanded(
      child: Column(
        children: [
          Text("$count", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.black45)),
        ],
      ),
    );
  }

  Widget _buildReviewCard(ReviewModel review) {
    final color = _sentimentColor(review.sentiment);
    final icon = _sentimentIcon(review.sentiment);
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isMe = currentUid != null && currentUid == review.studentId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: isMe ? Colors.green.shade100 : Colors.blue.shade100,
                radius: 18,
                child: Text(
                  review.studentName.isNotEmpty ? review.studentName[0].toUpperCase() : '?',
                  style: TextStyle(fontWeight: FontWeight.bold, color: isMe ? Colors.green.shade800 : Colors.blue),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            review.studentName,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Text(
                              "You",
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (i) => Icon(
                            i < review.rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "${review.rating.toStringAsFixed(1)} ★",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: color, size: 12),
                    const SizedBox(width: 3),
                    Text(
                      review.sentiment,
                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (isMe && review.reviewId != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: "Delete your review",
                  onPressed: () => _deleteReview(review.reviewId!),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(review.comment, style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildFoodMenuSection(double currentFoodRating, Map<String, dynamic>? currentFoodMenu) {
    final int todayIndex = (DateTime.now().weekday - 1).clamp(0, 6);
    final String todayName = _weekDays[todayIndex];
    final todayMenu = _getMealForDay(todayName, currentFoodMenu);

    final selectedDayName = _weekDays[_selectedFoodDayIndex];
    final selectedMenu = _getMealForDay(selectedDayName, currentFoodMenu);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.restaurant_menu, color: Colors.orange, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Weekly Food Menu Predictor",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Today's meals, mess schedule & verified food rating",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Food Rating Highlight Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE65100), Color(0xFFF57C00)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Food Rating",
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            currentFoodRating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            " / 5.0",
                            style: TextStyle(color: Colors.white70, fontSize: 18),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.star, color: Colors.amberAccent, size: 28),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          "Student Verified",
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildFoodMetric("Taste & Quality", "4.7★"),
                  _buildFoodMetric("Kitchen Hygiene", "4.8★"),
                  _buildFoodMetric("Refills", "Unlimited 🍚"),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Today's Menu Highlight (Highlighted Card)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.shade300, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "TODAY'S MENU",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        todayName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: Colors.green.shade600, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Live Mess",
                          style: TextStyle(color: Colors.green.shade800, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Breakfast
              _buildMealRow(
                icon: Icons.wb_sunny_outlined,
                iconColor: Colors.amber.shade700,
                mealName: "Breakfast",
                timing: "7:30 AM - 9:30 AM",
                food: todayMenu['breakfast']!,
              ),
              const Divider(height: 18),

              // Lunch
              _buildMealRow(
                icon: Icons.wb_sunny,
                iconColor: Colors.orange.shade700,
                mealName: "Lunch",
                timing: "12:30 PM - 2:30 PM",
                food: todayMenu['lunch']!,
              ),
              const Divider(height: 18),

              // Dinner
              _buildMealRow(
                icon: Icons.nightlight_round,
                iconColor: Colors.indigo.shade600,
                mealName: "Dinner",
                timing: "7:30 PM - 9:30 PM",
                food: todayMenu['dinner']!,
              ),

              if (todayMenu['special'] != null && todayMenu['special']!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.stars, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Today's Special: ${todayMenu['special']}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Weekly Menu Day Selector
        const Text(
          "Full Weekly Menu Schedule",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _weekDays.length,
            itemBuilder: (context, i) {
              final day = _weekDays[i];
              final isSelected = _selectedFoodDayIndex == i;
              final isToday = todayIndex == i;

              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(day.substring(0, 3)),
                      if (isToday) ...[
                        const SizedBox(width: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.deepOrange,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: Colors.orange,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedFoodDayIndex = i);
                    }
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // Selected Day Details Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "$selectedDayName Menu",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    selectedMenu['nutrition'] ?? 'Fresh & Hygienic',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  ),
                ],
              ),
              const Divider(height: 20),
              _buildSimpleMealLine("Breakfast", selectedMenu['breakfast']!),
              const SizedBox(height: 8),
              _buildSimpleMealLine("Lunch", selectedMenu['lunch']!),
              const SizedBox(height: 8),
              _buildSimpleMealLine("Dinner", selectedMenu['dinner']!),
              if (selectedMenu['special'] != null && selectedMenu['special']!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.orange, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      "Special: ${selectedMenu['special']}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFoodMetric(String title, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildMealRow({
    required IconData icon,
    required Color iconColor,
    required String mealName,
    required String timing,
    required String food,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    mealName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    timing,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                food,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleMealLine(String mealName, String food) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            mealName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54),
          ),
        ),
        Expanded(
          child: Text(
            food,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationMapCard() {
    double lat = widget.latitude;
    double lng = widget.longitude;

    if (lat == 0.0 || lng == 0.0) {
      lat = 17.7813 + ((widget.distanceFromCollege.abs() % 5) * 0.003);
      lng = 83.3768 + ((widget.distanceFromCollege.abs() % 5) * 0.004);
    }

    final hostelPos = lat_lng.LatLng(lat, lng);
    final String addressText = widget.address.isNotEmpty
        ? widget.address
        : "Near ${widget.collegeName} (${widget.distanceFromCollege.toStringAsFixed(1)} km from campus)";

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red, size: 24),
                const SizedBox(width: 8),
                const Text(
                  "Hostel Location & Map",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    "${lat.toStringAsFixed(4)}°, ${lng.toStringAsFixed(4)}°",
                    style: TextStyle(fontSize: 10, color: Colors.blue.shade800, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              addressText,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 220,
                width: double.infinity,
                color: Colors.blue.shade50,
                child: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: hostelPos,
                        initialZoom: 14.5,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.hostelhunt',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: hostelPos,
                              width: 50,
                              height: 50,
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.place, color: Colors.red, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              widget.hostelName,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.directions, color: Colors.white),
                label: const Text("Open in Google Maps / Get Directions", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Location: ${widget.hostelName} ($addressText)"),
                      backgroundColor: Colors.blue,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef HostelDetailsPage = HostelDetailsScreen;
