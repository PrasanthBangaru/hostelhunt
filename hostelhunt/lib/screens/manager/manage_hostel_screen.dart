import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';
import 'edit_hostel_screen.dart';

class ManageHostelScreen extends StatefulWidget {
  const ManageHostelScreen({super.key});

  @override
  State<ManageHostelScreen> createState() => _ManageHostelScreenState();
}

class _ManageHostelScreenState extends State<ManageHostelScreen> {
  final FirestoreService firestore = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Hostels"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore.getHostels(),
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
            itemCount: hostels.length,
            itemBuilder: (context, index) {
              final hostel = hostels[index];
              final data = hostel.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text(data["hostelName"] ?? ""),

                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("College : ${data["collegeName"] ?? ""}"),
                      Text("Base Price : ₹${data["price"] ?? 0}"),
                      Builder(builder: (context) {
                        // Safely calculate total price with extra facilities
                        int total = data["price"] ?? 0;
                        final costs = data["facilityCosts"];
                        if (costs != null) {
                          (costs as Map<String, dynamic>).forEach((_, v) {
                            total += (v as num).toInt();
                          });
                        }
                        return Text(
                          "Total Price : ₹$total/month",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        );
                      }),
                      Text("Vacancy : ${data["vacancy"] ?? 0}"),
                    ],
                  ),

                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.blue,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditHostelScreen(
                                hostel: hostel,
                              ),
                            ),
                          );
                        },
                      ),

                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.red,
                        ),
                        onPressed: () async {
                          await firestore.deleteHostel(hostel.id);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}