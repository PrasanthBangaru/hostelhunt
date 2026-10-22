import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../student/chat_screen.dart';

class ManagerChatsScreen extends StatelessWidget {
  const ManagerChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = FirebaseAuth.instance.currentUser;
    if (manager == null) {
      return const Scaffold(
        body: Center(child: Text("Please log in to view chats")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Bargaining & Chats"),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('managerId', isEqualTo: manager.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 70, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text(
                    "No negotiation chats yet.",
                    style: TextStyle(fontSize: 16, color: Colors.black45),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Students will reach out to you to negotiate rent.",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          final chats = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chatDoc = chats[index];
              final data = chatDoc.data() as Map<String, dynamic>;
              final studentName = data['studentName'] ?? 'Student';
              final hostelName = data['hostelName'] ?? 'Hostel';
              final lastMsg = data['lastMessage'] ?? '';
              final dealStatus = data['dealStatus'] ?? 'none';
              final currentOfferPrice = data['currentOfferPrice'] as int?;
              final offerSenderId = data['offerSenderId'] as String?;

              Widget? statusBadge;
              if (dealStatus == 'offered' && currentOfferPrice != null) {
                final isSentByStudent = offerSenderId != manager.uid;
                statusBadge = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSentByStudent ? Colors.orange.shade100 : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isSentByStudent ? "New Offer: ₹$currentOfferPrice" : "Countered: ₹$currentOfferPrice",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSentByStudent ? Colors.orange.shade800 : Colors.blue.shade800,
                    ),
                  ),
                );
              } else if (dealStatus == 'deal_closed' && currentOfferPrice != null) {
                statusBadge = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "🎉 Deal Closed: ₹$currentOfferPrice",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                  ),
                );
              } else if (dealStatus == 'deal_rejected') {
                statusBadge = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "Declined",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black45),
                  ),
                );
              }

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade50,
                    radius: 24,
                    child: Text(
                      studentName.isNotEmpty ? studentName[0].toUpperCase() : '?',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 20),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          studentName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      if (statusBadge != null) statusBadge,
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "🏫 $hostelName",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lastMsg,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          hostelId: data['hostelId'] ?? '',
                          hostelName: hostelName,
                          managerId: manager.uid,
                          originalPrice: data['originalPrice'] ?? 0,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
