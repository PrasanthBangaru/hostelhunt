import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_hostel_page.dart';

class ManageHostelScreen extends StatefulWidget {
  const ManageHostelScreen({super.key});

  @override
  State<ManageHostelScreen> createState() => _ManageHostelScreenState();
}

class _ManageHostelScreenState extends State<ManageHostelScreen> {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return const Scaffold(
        body: Center(child: Text("Not logged in.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Hostels"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("hostels")
            .where('managerId', isEqualTo: _uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.home_work_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "You haven't posted any hostels yet.",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
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
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  EditHostelScreen(hostel: hostel),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text("Delete Hostel"),
                              content: const Text(
                                  "Are you sure you want to delete this hostel?"),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text("Cancel"),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, true),
                                  child: const Text(
                                    "Delete",
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await FirebaseFirestore.instance
                                .collection("hostels")
                                .doc(hostel.id)
                                .delete();
                          }
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

typedef ManageHostelPage = ManageHostelScreen;
