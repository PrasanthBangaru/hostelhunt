import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as lat_lng;
import 'student_profile_page.dart';
import 'hostel_details_page.dart';
import 'price_predictor_page.dart';
import 'ai_chatbot_page.dart';

class _HostelModel {
  String? hostelId;
  String hostelName;
  String ownerName;
  String ownerPhone;
  String collegeName;
  String address;
  double latitude;
  double longitude;
  int price;
  int deposit;
  int vacancy;
  double rating;
  List<String> facilities;
  List<String> images;
  String description;
  Map<String, int> facilityCosts;
  String hostelType;
  double distanceFromCollege;
  String? managerId;

  _HostelModel({
    this.hostelId,
    required this.hostelName,
    required this.ownerName,
    required this.ownerPhone,
    required this.collegeName,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.price,
    required this.deposit,
    required this.vacancy,
    required this.rating,
    required this.facilities,
    required this.images,
    required this.description,
    this.facilityCosts = const {},
    this.hostelType = "Co-Ed",
    this.distanceFromCollege = 0.0,
    this.managerId,
  });
}

class HostelCard extends StatelessWidget {
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

  const HostelCard({
    super.key,
    required this.hostelId,
    required this.hostelName,
    required this.collegeName,
    required this.price,
    required this.vacancy,
    required this.facilities,
    this.facilityCosts = const {},
    this.imageUrl,
    this.hostelType = "Co-Ed",
    this.distanceFromCollege = 0.0,
    this.managerId,
    this.address = "",
    this.latitude = 0.0,
    this.longitude = 0.0,
  });

  int get totalPrice =>
      price + facilityCosts.values.fold(0, (prev, cost) => prev + cost);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hostelName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text("🏫 College : $collegeName"),
            if (address.isNotEmpty) Text("📍 Location : $address", style: TextStyle(color: Colors.grey.shade700)),
            Text("🛏 Vacancy : $vacancy Beds"),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: hostelType == "Boys"
                        ? Colors.blue.shade50
                        : hostelType == "Girls"
                            ? Colors.pink.shade50
                            : Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: hostelType == "Boys"
                          ? Colors.blue.shade200
                          : hostelType == "Girls"
                              ? Colors.pink.shade200
                              : Colors.purple.shade200,
                    ),
                  ),
                  child: Text(
                    "🚻 $hostelType Hostel",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: hostelType == "Boys"
                          ? Colors.blue.shade800
                          : hostelType == "Girls"
                              ? Colors.pink.shade800
                              : Colors.purple.shade800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(Icons.directions_walk, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 2),
                Text(
                  "${distanceFromCollege.toStringAsFixed(1)} km to College",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Price Breakdown
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Base Price (Bed + Food + WiFi)",
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                      Text(
                        "₹$price/mo",
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  ...facilityCosts.entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${e.key} (extra)",
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.orange,
                            ),
                          ),
                          Text(
                            "+₹${e.value}/mo",
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (facilityCosts.isNotEmpty) const Divider(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Total",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        "₹$totalPrice/month",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Facility chips
            Wrap(
              spacing: 8,
              children: facilities.map(
                (facility) => Chip(
                  label: Text(facility),
                  backgroundColor: Colors.blue.shade50,
                ),
              ).toList(),
            ),
            const SizedBox(height: 15),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HostelDetailsScreen(
                        hostelId: hostelId,
                        hostelName: hostelName,
                        collegeName: collegeName,
                        price: price,
                        vacancy: vacancy,
                        facilities: facilities,
                        facilityCosts: facilityCosts,
                        imageUrl: imageUrl,
                        hostelType: hostelType,
                        distanceFromCollege: distanceFromCollege,
                        managerId: managerId,
                        address: address,
                        latitude: latitude,
                        longitude: longitude,
                      ),
                    ),
                  );
                },
                child: const Text("View Details"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  String _searchQuery = "";
  late Stream<QuerySnapshot> _hostelsStream;
  bool _isMapView = false;

  // Filter States
  bool _filterBoys = false;
  bool _filterGirls = false;
  bool _filterCoEd = false;
  bool _filterDist1 = false; // <= 1.0 km
  bool _filterDist2 = false; // <= 2.0 km
  bool _filterDist3 = false; // <= 3.0 km
  double _minPrice = 0.0;
  double _maxPrice = 25000.0;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _hostelsStream = FirebaseFirestore.instance.collection("hostels").snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("HostelHunt"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isMapView ? Icons.format_list_bulleted : Icons.map_outlined),
            tooltip: _isMapView ? 'List View' : 'Map View',
            onPressed: () {
              setState(() {
                _isMapView = !_isMapView;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Rent Predictor',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PricePredictorScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'My Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const StudentProfileScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _hostelsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shield_outlined, color: Colors.orange, size: 60),
                        const SizedBox(height: 15),
                        const Text(
                          "Firebase Permission Blocked",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Your Firebase project 'hostelhunt-new' currently has Security Rules blocking database reads.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black87, fontSize: 14),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: const SelectableText(
                            "rules_version = '2';\nservice cloud.firestore {\n  match /databases/{database}/documents {\n    match /{document=**} {\n      allow read, write: if true;\n    }\n  }\n}",
                            style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                          ),
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          "Paste the rule above into your Firebase Console ➔ Firestore Database ➔ Rules tab and click Publish.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          List<Map<String, dynamic>> allHostelData = [];

          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            for (var doc in snapshot.data!.docs) {
              final d = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
              d["id"] = doc.id;
              allHostelData.add(d);
            }
          }

          if (allHostelData.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  "No Hostels Found in Firebase Database",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }

          // Extract unique college names for suggestions
          final Set<String> collegeNamesSet = {};
          for (var data in allHostelData) {
            final collegeName = data["collegeName"] as String?;
            if (collegeName != null && collegeName.trim().isNotEmpty) {
              collegeNamesSet.add(collegeName.trim());
            }
          }
          final List<String> allColleges = collegeNamesSet.toList();

          // Filter hostels based on search query and selected filters
          final filteredHostels = allHostelData.where((data) {
            // 1. Search Query Filter (college name)
            if (_searchQuery.isNotEmpty) {
              final collegeName = (data["collegeName"] ?? "").toString().toLowerCase();
              if (!collegeName.contains(_searchQuery.toLowerCase())) {
                return false;
              }
            }

            // 2. Hostel Type Filter
            final type = data["hostelType"] ?? "Co-Ed";
            bool matchesType = false;
            if (!_filterBoys && !_filterGirls && !_filterCoEd) {
              matchesType = true;
            } else {
              if (_filterBoys && type == "Boys") matchesType = true;
              if (_filterGirls && type == "Girls") matchesType = true;
              if (_filterCoEd && type == "Co-Ed") matchesType = true;
            }
            if (!matchesType) return false;

            // 3. Distance Filter
            final distance = (data["distanceFromCollege"] as num?)?.toDouble() ?? 0.0;
            bool matchesDistance = false;
            if (!_filterDist1 && !_filterDist2 && !_filterDist3) {
              matchesDistance = true;
            } else {
              if (_filterDist1 && distance <= 1.0) matchesDistance = true;
              if (_filterDist2 && distance <= 2.0) matchesDistance = true;
              if (_filterDist3 && distance <= 3.0) matchesDistance = true;
            }
            if (!matchesDistance) return false;

            // 4. Price Filter
            final price = data["price"] ?? 0;
            if (price < _minPrice || price > _maxPrice) {
              return false;
            }

            return true;
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Autocomplete<String>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<String>.empty();
                          }
                          return allColleges.where((String option) {
                            return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                          });
                        },
                        onSelected: (String selection) {
                          setState(() {
                            _searchQuery = selection;
                          });
                        },
                        fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                            },
                            decoration: InputDecoration(
                              hintText: "Search by College Name",
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _showFilters = !_showFilters;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _showFilters ? Colors.blue : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: _showFilters ? Colors.blue : Colors.grey.shade300,
                          ),
                        ),
                        child: Icon(
                          Icons.filter_alt_outlined,
                          color: _showFilters ? Colors.white : Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),

                // Collapsible Filter Panel
                if (_showFilters) ...[
                  const SizedBox(height: 15),
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Filters",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Divider(),
                          
                          // 1. Hostel Type Filter
                          const Text("Hostel Type", style: TextStyle(fontWeight: FontWeight.w600)),
                          Row(
                            children: [
                              FilterChip(
                                label: const Text("Boys"),
                                selected: _filterBoys,
                                onSelected: (val) {
                                  setState(() => _filterBoys = val);
                                },
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                label: const Text("Girls"),
                                selected: _filterGirls,
                                onSelected: (val) {
                                  setState(() => _filterGirls = val);
                                },
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                label: const Text("Co-Ed"),
                                selected: _filterCoEd,
                                onSelected: (val) {
                                  setState(() => _filterCoEd = val);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),

                          // 2. Distance Filter
                          const Text("Distance from College", style: TextStyle(fontWeight: FontWeight.w600)),
                          Wrap(
                            spacing: 8,
                            children: [
                              FilterChip(
                                label: const Text("≤ 1 km"),
                                selected: _filterDist1,
                                onSelected: (val) => setState(() => _filterDist1 = val),
                              ),
                              FilterChip(
                                label: const Text("≤ 2 km"),
                                selected: _filterDist2,
                                onSelected: (val) => setState(() => _filterDist2 = val),
                              ),
                              FilterChip(
                                label: const Text("≤ 3 km"),
                                selected: _filterDist3,
                                onSelected: (val) => setState(() => _filterDist3 = val),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),

                          // 3. Price Filter Range Slider
                          Text(
                            "Price Range: ₹${_minPrice.round()} - ₹${_maxPrice.round()}",
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          RangeSlider(
                            values: RangeValues(_minPrice, _maxPrice),
                            min: 0,
                            max: 25000,
                            divisions: 50,
                            labels: RangeLabels(
                              "₹${_minPrice.round()}",
                              "₹${_maxPrice.round()}",
                            ),
                            onChanged: (RangeValues values) {
                              setState(() {
                                _minPrice = values.start;
                                _maxPrice = values.end;
                              });
                            },
                          ),

                          // Clear Filters Button
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  _filterBoys = false;
                                  _filterGirls = false;
                                  _filterCoEd = false;
                                  _filterDist1 = false;
                                  _filterDist2 = false;
                                  _filterDist3 = false;
                                  _minPrice = 0.0;
                                  _maxPrice = 25000.0;
                                  _searchQuery = "";
                                });
                              },
                              child: const Text("Clear All Filters"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Recommended Hostels Carousel
                if (_searchQuery.isEmpty && !_showFilters) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: const [
                      Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                      SizedBox(width: 6),
                      Text(
                        "AI Recommended Hostels",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 165,
                    child: Builder(
                      builder: (context) {
                        final hostelModels = allHostelData.map((d) {
                          Map<String, int> fc = {};
                          final raw = d['facilityCosts'];
                          if (raw != null) {
                            (raw as Map<String, dynamic>).forEach((k, v) {
                              fc[k] = (v as num).toInt();
                            });
                          }
                          return _HostelModel(
                            hostelId: d['id'],
                            hostelName: d['hostelName'] ?? '',
                            ownerName: d['ownerName'] ?? '',
                            ownerPhone: d['ownerPhone'] ?? '',
                            collegeName: d['collegeName'] ?? '',
                            address: d['address'] ?? '',
                            latitude: (d['latitude'] as num?)?.toDouble() ?? 0.0,
                            longitude: (d['longitude'] as num?)?.toDouble() ?? 0.0,
                            price: d['price'] ?? 0,
                            deposit: d['deposit'] ?? 0,
                            vacancy: d['vacancy'] ?? 0,
                            rating: (d['rating'] as num?)?.toDouble() ?? 0.0,
                            facilities: List<String>.from(d['facilities'] ?? []),
                            images: List<String>.from(d['images'] ?? []),
                            description: d['description'] ?? '',
                            facilityCosts: fc,
                            hostelType: d['hostelType'] ?? 'Co-Ed',
                            distanceFromCollege: (d['distanceFromCollege'] as num?)?.toDouble() ?? 0.0,
                            managerId: d['managerId'],
                          );
                        }).toList();

                        // Local scoring: higher rating + lower price + lower distance = better
                        hostelModels.sort((a, b) {
                          double scoreA = (a.rating * 20) - (a.price / 500.0) - (a.distanceFromCollege * 5);
                          double scoreB = (b.rating * 20) - (b.price / 500.0) - (b.distanceFromCollege * 5);
                          return scoreB.compareTo(scoreA);
                        });

                        final topRecs = hostelModels.take(5).toList();
                        if (topRecs.isEmpty) {
                          return const Center(child: Text("No hostels available yet."));
                        }

                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: topRecs.length,
                          itemBuilder: (context, i) {
                            final h = topRecs[i];
                            final colors = [
                              const Color(0xFF1565C0),
                              const Color(0xFF6A1B9A),
                              const Color(0xFF00695C),
                              const Color(0xFFE65100),
                              const Color(0xFF37474F),
                            ];
                            final color = colors[i % colors.length];
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => HostelDetailsScreen(
                                      hostelId: h.hostelId ?? '',
                                      hostelName: h.hostelName,
                                      collegeName: h.collegeName,
                                      price: h.price,
                                      vacancy: h.vacancy,
                                      facilities: h.facilities,
                                      facilityCosts: h.facilityCosts,
                                      hostelType: h.hostelType,
                                      distanceFromCollege: h.distanceFromCollege,
                                      managerId: h.managerId,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                width: 200,
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [color, color.withValues(alpha: 0.75)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.white24,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            "#${i + 1} Pick",
                                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const Spacer(),
                                        const Icon(Icons.star, color: Colors.amber, size: 14),
                                        Text(
                                          h.rating.toStringAsFixed(1),
                                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      h.hostelName,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      "${h.distanceFromCollege.toStringAsFixed(1)} km • ${h.hostelType}",
                                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                                    ),
                                    Text(
                                      "₹${h.price}/mo",
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                                    ),
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

                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _searchQuery.isEmpty ? "All Hostels" : "Search Results",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "${filteredHostels.length} hostels found",
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                if (filteredHostels.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text("No hostels found matching filters"),
                    ),
                  )
                else if (_isMapView)
                  _buildFullMapView(filteredHostels)
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredHostels.length,
                    itemBuilder: (context, index) {
                      final data = filteredHostels[index];
                      final facilities = List<String>.from(data["facilities"] ?? []);

                      Map<String, int> facilityCosts = {};
                      final rawCosts = data["facilityCosts"];
                      if (rawCosts != null) {
                        (rawCosts as Map<String, dynamic>).forEach((key, value) {
                          facilityCosts[key] = (value as num).toInt();
                        });
                      }

                      return HostelCard(
                        hostelId: data["id"] ?? "",
                        hostelName: data["hostelName"] ?? "",
                        collegeName: data["collegeName"] ?? "",
                        price: data["price"] ?? 0,
                        vacancy: data["vacancy"] ?? 0,
                        facilities: facilities,
                        facilityCosts: facilityCosts,
                        imageUrl: data["imageUrl"],
                        hostelType: data["hostelType"] ?? "Co-Ed",
                        distanceFromCollege: (data["distanceFromCollege"] as num?)?.toDouble() ?? 0.0,
                        managerId: data["managerId"],
                        address: data["address"] ?? "",
                        latitude: (data["latitude"] as num?)?.toDouble() ?? 0.0,
                        longitude: (data["longitude"] as num?)?.toDouble() ?? 0.0,
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AIChatbotScreen(),
            ),
          );
        },
        label: const Text("AI Chatbot"),
        icon: const Icon(Icons.psychology),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildFullMapView(List<Map<String, dynamic>> hostels) {
    List<Marker> mapMarkers = [];
    lat_lng.LatLng defaultCenter = const lat_lng.LatLng(17.7813, 83.3768);

    for (int i = 0; i < hostels.length; i++) {
      final h = hostels[i];
      final id = (h["id"] ?? i.toString()).toString();
      final name = (h["hostelName"] ?? "Hostel").toString();
      final price = h["price"] ?? 0;
      final type = (h["hostelType"] ?? "Co-Ed").toString();
      final dist = (h["distanceFromCollege"] as num?)?.toDouble() ?? 0.0;
      final rawLat = (h["latitude"] as num?)?.toDouble() ?? 0.0;
      final rawLng = (h["longitude"] as num?)?.toDouble() ?? 0.0;

      double lat = rawLat != 0.0 ? rawLat : 17.7813 + (((i + 1) * 0.003) * (i.isEven ? 1 : -1));
      double lng = rawLng != 0.0 ? rawLng : 83.3768 + (((i + 1) * 0.004) * (i.isOdd ? 1 : -1));
      final pos = lat_lng.LatLng(lat, lng);

      mapMarkers.add(
        Marker(
          point: pos,
          width: 70,
          height: 60,
          child: GestureDetector(
            onTap: () {
              final facilities = List<String>.from(h["facilities"] ?? []);
              Map<String, int> facilityCosts = {};
              final rawCosts = h["facilityCosts"];
              if (rawCosts != null) {
                (rawCosts as Map<String, dynamic>).forEach((k, v) {
                  facilityCosts[k] = (v as num).toInt();
                });
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HostelDetailsScreen(
                    hostelId: id,
                    hostelName: name,
                    collegeName: h["collegeName"] ?? "",
                    price: price,
                    vacancy: h["vacancy"] ?? 0,
                    facilities: facilities,
                    facilityCosts: facilityCosts,
                    imageUrl: h["imageUrl"],
                    hostelType: type,
                    distanceFromCollege: dist,
                    managerId: h["managerId"],
                    address: h["address"] ?? "",
                    latitude: lat,
                    longitude: lng,
                  ),
                ),
              );
            },
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade800,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "₹$price",
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 32,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      height: 480,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: FlutterMap(
              options: MapOptions(
                initialCenter: defaultCenter,
                initialZoom: 13.5,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.hostelhunt',
                ),
                MarkerLayer(markers: mapMarkers),
              ],
            ),
          ),
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: Text(
                "🗺️ Showing ${hostels.length} hostels on map",
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text("Tap a hostel below to view on map:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 75,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: hostels.length,
                    itemBuilder: (context, i) {
                      final h = hostels[i];
                      final name = (h["hostelName"] ?? "Hostel").toString();
                      final price = h["price"] ?? 0;
                      final type = (h["hostelType"] ?? "Co-Ed").toString();
                      final dist = (h["distanceFromCollege"] as num?)?.toDouble() ?? 0.0;
                      final rawLat = (h["latitude"] as num?)?.toDouble() ?? 0.0;
                      final rawLng = (h["longitude"] as num?)?.toDouble() ?? 0.0;
                      double lat = rawLat != 0.0 ? rawLat : 17.7813 + (((i + 1) * 0.003) * (i.isEven ? 1 : -1));
                      double lng = rawLng != 0.0 ? rawLng : 83.3768 + (((i + 1) * 0.004) * (i.isOdd ? 1 : -1));

                      return GestureDetector(
                        onTap: () {
                          final facilities = List<String>.from(h["facilities"] ?? []);
                          Map<String, int> facilityCosts = {};
                          final rawCosts = h["facilityCosts"];
                          if (rawCosts != null) {
                            (rawCosts as Map<String, dynamic>).forEach((k, v) {
                              facilityCosts[k] = (v as num).toInt();
                            });
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HostelDetailsScreen(
                                hostelId: (h["id"] ?? i.toString()).toString(),
                                hostelName: name,
                                collegeName: h["collegeName"] ?? "",
                                price: price,
                                vacancy: h["vacancy"] ?? 0,
                                facilities: facilities,
                                facilityCosts: facilityCosts,
                                imageUrl: h["imageUrl"],
                                hostelType: type,
                                distanceFromCollege: dist,
                                managerId: h["managerId"],
                                address: h["address"] ?? "",
                                latitude: lat,
                                longitude: lng,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 170,
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade100),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text("₹$price/mo • $type", style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text("📍 ${dist.toStringAsFixed(1)} km to college", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

typedef StudentHomePage = StudentHomeScreen;
