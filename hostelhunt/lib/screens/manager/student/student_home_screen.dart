import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../widgets/hostel_card.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("HostelHunt"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: "Search by College Name",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            const SizedBox(height: 25),
            const Text(
              "Popular Hostels",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection("hostels").snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text("No Hostels Found"),
                  );
                }

                final hostels = snapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: hostels.length,
                  itemBuilder: (context, index) {
                    final hostel = hostels[index];
                    final data = hostel.data() as Map<String, dynamic>;

                    final facilities = List<String>.from(data["facilities"] ?? []);

                    // Safely parse facilityCosts — field may not exist on old documents
                    Map<String, int> facilityCosts = {};
                    final rawCosts = data["facilityCosts"];
                    if (rawCosts != null) {
                      (rawCosts as Map<String, dynamic>).forEach((key, value) {
                        facilityCosts[key] = (value as num).toInt();
                      });
                    }

                    return HostelCard(
                      hostelName: data["hostelName"] ?? "",
                      collegeName: data["collegeName"] ?? "",
                      price: data["price"] ?? 0,
                      vacancy: data["vacancy"] ?? 0,
                      facilities: facilities,
                      facilityCosts: facilityCosts,
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
