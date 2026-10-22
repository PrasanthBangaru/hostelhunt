import 'package:flutter/material.dart';
import '../screens/manager/student/hostel_details_screen.dart';

class HostelCard extends StatelessWidget {
  final String hostelId;
  final String hostelName;
  final String collegeName;
  final int price;           // Base price
  final int vacancy;
  final List<String> facilities;
  final Map<String, int> facilityCosts; // Extra facility costs
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

  /// Total price = base + all extra facility costs
  int get totalPrice =>
      price + facilityCosts.values.fold(0, (sum, cost) => sum + cost);

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

            // ── Price Breakdown ─────────────────────────────
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
                  // Base price row
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

                  // Extra facility cost rows
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

                  // Total price row
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