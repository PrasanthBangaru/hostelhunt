import 'package:flutter/material.dart';

class HostelCard extends StatelessWidget {
  final String hostelName;
  final String collegeName;
  final int price;           // Base price
  final int vacancy;
  final List<String> facilities;
  final Map<String, int> facilityCosts; // Extra facility costs

  const HostelCard({
    super.key,
    required this.hostelName,
    required this.collegeName,
    required this.price,
    required this.vacancy,
    required this.facilities,
    this.facilityCosts = const {},
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
            Text("🛏 Vacancy : $vacancy Beds"),

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
                onPressed: () {},
                child: const Text("View Details"),
              ),
            ),

          ],
        ),
      ),
    );
  }
}