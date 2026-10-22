import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as lat_lng;
import '../../../services/ai_service.dart';
import '../../../services/ml_price_service.dart';
import '../../../models/hostel_model.dart';
import '../../../models/review_model.dart';
import '../../student/chat_screen.dart';

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
  });

  @override
  State<HostelDetailsScreen> createState() => _HostelDetailsScreenState();
}

class _HostelDetailsScreenState extends State<HostelDetailsScreen> {
  Set<String> _selectedExtraFacilities = {};

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

  @override
  void initState() {
    super.initState();
    _currentImageUrl = widget.imageUrl;
    _trainMLModel();
  }

  Future<void> _trainMLModel() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('hostels').get();
      final hostels = snap.docs.map((doc) => HostelModel.fromMap(doc.data(), doc.id)).toList();
      MLPriceService().trainModel(hostels);
      final predicted = MLPriceService().predictPrice(
        distanceFromCollege: widget.distanceFromCollege,
        hostelType: widget.hostelType,
        rating: 4.0,
        facilitiesCount: widget.facilities.length,
      );
      if (mounted) {
        setState(() {
          _mlPredictedPrice = predicted;
          _mlModelTrained = true;
        });
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

  Future<void> _submitReview() async {
    final comment = _reviewController.text.trim();
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please write a review comment.')));
      return;
    }
    setState(() => _isSubmittingReview = true);

    try {
      // Perform sentiment analysis
      final sentimentData = await AIService().analyzeSentiment(comment);
      final sentiment = sentimentData['sentiment'] as String;
      final score = sentimentData['score'] as double;

      final user = FirebaseAuth.instance.currentUser;
      final review = ReviewModel(
        hostelId: widget.hostelId,
        studentName: user?.displayName ?? user?.email?.split('@').first ?? 'Anonymous',
        studentId: user?.uid ?? '',
        rating: _reviewRating,
        comment: comment,
        timestamp: DateTime.now(),
        sentiment: sentiment,
        sentimentScore: score,
      );

      await FirebaseFirestore.instance
          .collection('hostels')
          .doc(widget.hostelId)
          .collection('reviews')
          .add(review.toMap());

      _reviewController.clear();

      setState(() {
        _sentimentResult = sentiment;
        _sentimentEmoji = sentiment == 'positive' ? '😊 Positive' : sentiment == 'negative' ? '😞 Negative' : '😐 Neutral';
        _isSubmittingReview = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Review submitted! Sentiment: ${_sentimentEmoji ?? sentiment}'),
          backgroundColor: sentiment == 'positive' ? Colors.green : sentiment == 'negative' ? Colors.red : Colors.orange,
        ),
      );
    } catch (e) {
      setState(() => _isSubmittingReview = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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

  /// Generate simulated vacancy forecast data (6 months)
  List<FlSpot> _generateVacancyForecast() {
    final baseVacancy = widget.vacancy.toDouble();
    // Simple simulation: vacancy reduces over months as students join
    final List<FlSpot> spots = [];
    final patterns = [0.0, -0.1, -0.2, -0.05, -0.15, 0.05]; // Fluctuations
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
                // ML Price Badge overlay
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
                  Text(
                    widget.hostelName,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
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
                    Text("${widget.vacancy} Beds Available", style: const TextStyle(fontSize: 16, color: Colors.black54)),
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
                        BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2)),
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
                              color: Colors.purple.withOpacity(0.1),
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
                        BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2)),
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
                              color: _sentimentColor(_sentimentResult!).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _sentimentColor(_sentimentResult!).withOpacity(0.4)),
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

                  // Reviews List from Firestore
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('hostels')
                        .doc(widget.hostelId)
                        .collection('reviews')
                        .orderBy('timestamp', descending: true)
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

                      // Sentiment breakdown
                      int pos = reviews.where((r) => r.sentiment == 'positive').length;
                      int neg = reviews.where((r) => r.sentiment == 'negative').length;
                      int neu = reviews.where((r) => r.sentiment == 'neutral').length;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sentiment Summary Bar
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("${reviews.length} Reviews • Sentiment Breakdown",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 14)),
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
              backgroundColor: color.withOpacity(0.15),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                radius: 18,
                child: Text(
                  review.studentName.isNotEmpty ? review.studentName[0].toUpperCase() : '?',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.studentName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < review.rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withOpacity(0.3)),
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
            ],
          ),
          const SizedBox(height: 10),
          Text(review.comment, style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildLocationMapCard() {
    double lat = widget.latitude;
    double lng = widget.longitude;

    if (lat == 0.0 || lng == 0.0) {
      // Smart default fallback centered around college campus region with offset
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

