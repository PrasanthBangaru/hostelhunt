import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_page.dart';

class ManagerJoinRequestsScreen extends StatefulWidget {
  final String? initialFilterHostelId;

  const ManagerJoinRequestsScreen({super.key, this.initialFilterHostelId});

  @override
  State<ManagerJoinRequestsScreen> createState() => _ManagerJoinRequestsScreenState();
}

class _ManagerJoinRequestsScreenState extends State<ManagerJoinRequestsScreen> {
  String _selectedFilter = 'all'; // 'all', 'pending', 'accepted', 'rejected'
  final String? _managerUid = FirebaseAuth.instance.currentUser?.uid;

  Future<void> _updateRequestStatus(
      BuildContext context, String requestId, String newStatus, String hostelId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance
          .collection('join_requests')
          .doc(requestId)
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // If accepted, decrement vacancy by 1 if vacancy > 0
      if (newStatus == 'accepted' && hostelId.isNotEmpty) {
        final hostelRef =
            FirebaseFirestore.instance.collection('hostels').doc(hostelId);
        final hostelDoc = await hostelRef.get();
        if (hostelDoc.exists) {
          final currentVac =
              (hostelDoc.data()?['vacancy'] as num?)?.toInt() ?? 0;
          if (currentVac > 0) {
            await hostelRef.update({'vacancy': currentVac - 1});
          }
        }
      }

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(newStatus == 'accepted'
              ? 'Request accepted! Vacancy updated.'
              : 'Request marked as $newStatus.'),
          backgroundColor:
              newStatus == 'accepted' ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_managerUid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Student Join Requests")),
        body: const Center(child: Text("Please login as a manager")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text("Student Join Requests"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('⏳ Pending', 'pending', Colors.orange),
                  const SizedBox(width: 8),
                  _buildFilterChip('✅ Accepted', 'accepted', Colors.green),
                  const SizedBox(width: 8),
                  _buildFilterChip('❌ Declined', 'rejected', Colors.red),
                ],
              ),
            ),
          ),

          // Realtime Stream of Requests for this manager
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('join_requests')
                  .where('managerId', isEqualTo: _managerUid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text("Error loading requests: ${snapshot.error}"),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                List<QueryDocumentSnapshot> docs = snapshot.data!.docs;

                // Client-side sort by createdAt descending
                docs.sort((a, b) {
                  final aTime = (a.data() as Map<String, dynamic>)['createdAt']
                      as Timestamp?;
                  final bTime = (b.data() as Map<String, dynamic>)['createdAt']
                      as Timestamp?;
                  if (aTime == null || bTime == null) return 0;
                  return bTime.compareTo(aTime);
                });

                // Filter by status if selected
                if (_selectedFilter != 'all') {
                  docs = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    return (data['status'] ?? 'pending')
                            .toString()
                            .toLowerCase() ==
                        _selectedFilter;
                  }).toList();
                }

                // Filter by specific hostel if passed
                if (widget.initialFilterHostelId != null) {
                  docs = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    return data['hostelId'] == widget.initialFilterHostelId;
                  }).toList();
                }

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.filter_list_off,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          "No requests in '$_selectedFilter'",
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildRequestCard(doc.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, [Color? activeColor]) {
    final bool isSelected = _selectedFilter == value;
    final color = activeColor ?? Theme.of(context).primaryColor;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _selectedFilter = value);
      },
      selectedColor: color.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? color : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? color : Colors.grey.shade300,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.inbox_outlined,
                  size: 64, color: Colors.blue.shade600),
            ),
            const SizedBox(height: 20),
            const Text(
              "No Join Requests Yet",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "When students view your hostel and tap 'Request to Join', their applications will appear here in real time.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(String requestId, Map<String, dynamic> data) {
    final studentName = data['studentName']?.toString() ?? 'Student';
    final studentPhone =
        data['studentPhone']?.toString() ?? 'No phone provided';
    final studentEmail = data['studentEmail']?.toString() ?? '';
    final hostelName = data['hostelName']?.toString() ?? 'Hostel';
    final monthlyRent = (data['monthlyRent'] as num?)?.toInt() ?? 0;
    final moveInDate = data['moveInDate']?.toString() ?? 'Flexible';
    final note = data['note']?.toString() ?? '';
    final status = (data['status']?.toString() ?? 'pending').toLowerCase();
    final List<dynamic> facilities =
        (data['selectedFacilities'] as List<dynamic>?) ?? [];
    final hostelId = data['hostelId']?.toString() ?? '';

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (status == 'accepted') {
      statusColor = Colors.green;
      statusText = 'Accepted';
      statusIcon = Icons.check_circle;
    } else if (status == 'rejected') {
      statusColor = Colors.red;
      statusText = 'Declined';
      statusIcon = Icons.cancel;
    } else {
      statusColor = Colors.orange;
      statusText = 'Pending Approval';
      statusIcon = Icons.hourglass_top;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Student Avatar, Name, and Status Badge
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    studentName.isNotEmpty
                        ? studentName[0].toUpperCase()
                        : 'S',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentName,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Applying for: $hostelName",
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            // Key Details Grid
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Estimated Monthly Rent:",
                          style:
                              TextStyle(color: Colors.black54, fontSize: 13)),
                      Text("₹$monthlyRent/mo",
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Preferred Move-in:",
                          style:
                              TextStyle(color: Colors.black54, fontSize: 13)),
                      Text(moveInDate,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Student Phone:",
                          style:
                              TextStyle(color: Colors.black54, fontSize: 13)),
                      Text(studentPhone,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87)),
                    ],
                  ),
                  if (studentEmail.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Student Email:",
                            style: TextStyle(
                                color: Colors.black54, fontSize: 13)),
                        Flexible(
                          child: Text(studentEmail,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black87)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Extra Facilities
            if (facilities.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: facilities.map((f) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Text(
                      "+ $f",
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w500),
                    ),
                  );
                }).toList(),
              ),
            ],

            // Student Note / Message
            if (note.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.chat_bubble_outline,
                        size: 16, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "\"$note\"",
                        style: const TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                // Chat button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final studentId = data['studentId']?.toString() ?? '';
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            chatId: studentId.isNotEmpty
                                ? "${studentId}_${_managerUid}_$hostelId"
                                : null,
                            hostelId: hostelId,
                            hostelName: hostelName,
                            managerId: _managerUid!,
                            studentId: studentId.isNotEmpty ? studentId : null,
                            originalPrice: monthlyRent,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.message, size: 16),
                    label: const Text("Chat"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                if (status == 'pending') ...[
                  // Decline button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _updateRequestStatus(
                          context, requestId, 'rejected', hostelId),
                      icon: const Icon(Icons.close,
                          size: 16, color: Colors.red),
                      label: const Text("Decline",
                          style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Accept button
                  Expanded(
                    flex: 1,
                    child: ElevatedButton.icon(
                      onPressed: () => _updateRequestStatus(
                          context, requestId, 'accepted', hostelId),
                      icon: const Icon(Icons.check,
                          size: 16, color: Colors.white),
                      label: const Text("Accept",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ] else ...[
                  // Status change reset button
                  TextButton.icon(
                    onPressed: () => _updateRequestStatus(
                        context, requestId, 'pending', hostelId),
                    icon: const Icon(Icons.undo, size: 16),
                    label: const Text("Reopen"),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
