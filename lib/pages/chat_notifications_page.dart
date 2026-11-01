import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'chat_page.dart';

/// An interactive Notification Button that displays real-time unread message badges
/// and opens the Message Notifications drawer/sheet.
class ChatNotificationButton extends StatelessWidget {
  final bool isManager;
  final Color? iconColor;

  const ChatNotificationButton({
    super.key,
    required this.isManager,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final query = FirebaseFirestore.instance
        .collection('chats')
        .where(isManager ? 'managerId' : 'studentId', isEqualTo: user.uid);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        int unreadCount = 0;
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            // Avoid self-chats
            if (isManager && data['studentId'] == user.uid) continue;

            final isUnread = isManager
                ? (data['unreadByManager'] == true ||
                    (data['unreadByManager'] == null &&
                        data['lastSenderId'] != null &&
                        data['lastSenderId'] != user.uid))
                : (data['unreadByStudent'] == true ||
                    (data['unreadByStudent'] == null &&
                        data['lastSenderId'] != null &&
                        data['lastSenderId'] != user.uid));

            if (isUnread) unreadCount++;
          }
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(
                unreadCount > 0
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_outlined,
                color: iconColor,
                size: 26,
              ),
              tooltip: "Message Notifications (${unreadCount > 0 ? '$unreadCount new' : 'No new messages'})",
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => ChatNotificationsSheet(isManager: isManager),
                );
              },
            ),
            if (unreadCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withValues(alpha: 0.5),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Center(
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The Message Notifications Sheet listing all conversations and allowing quick navigation
class ChatNotificationsSheet extends StatelessWidget {
  final bool isManager;

  const ChatNotificationsSheet({super.key, required this.isManager});

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return '';
    }

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24 && date.day == now.day) {
      return DateFormat('h:mm a').format(date);
    } else if (difference.inDays < 7) {
      return DateFormat('E, h:mm a').format(date);
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  Future<void> _markAllAsRead(List<QueryDocumentSnapshot> docs, String uid) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in docs) {
      batch.update(doc.reference, {
        isManager ? 'unreadByManager' : 'unreadByStudent': false,
      });
    }
    await batch.commit().catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: const Center(child: Text("Please log in to view notifications")),
      );
    }

    final query = FirebaseFirestore.instance
        .collection('chats')
        .where(isManager ? 'managerId' : 'studentId', isEqualTo: user.uid);

    final sheetHeight = MediaQuery.of(context).size.height * 0.8;

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Header
          StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              final rawDocs = snapshot.data?.docs ?? [];
              final docs = rawDocs.where((doc) {
                final d = doc.data() as Map<String, dynamic>;
                if (isManager && d['studentId'] == user.uid) return false;
                return true;
              }).toList();

              final hasUnread = docs.any((doc) {
                final d = doc.data() as Map<String, dynamic>;
                return isManager
                    ? (d['unreadByManager'] == true ||
                        (d['unreadByManager'] == null &&
                            d['lastSenderId'] != null &&
                            d['lastSenderId'] != user.uid))
                    : (d['unreadByStudent'] == true ||
                        (d['unreadByStudent'] == null &&
                            d['lastSenderId'] != null &&
                            d['lastSenderId'] != user.uid));
              });

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isManager
                              ? [Colors.blue.shade600, Colors.indigo.shade600]
                              : [Colors.teal.shade600, Colors.green.shade600],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Message Notifications",
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            isManager ? "Student inquiries & offers" : "Hostel manager updates & responses",
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    if (hasUnread)
                      TextButton.icon(
                        onPressed: () => _markAllAsRead(docs, user.uid),
                        icon: const Icon(Icons.done_all, size: 16),
                        label: const Text("Read All", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              );
            },
          ),

          // Messages list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.chat_bubble_outline_rounded, size: 54, color: Colors.blue.shade300),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            "No message notifications",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isManager
                                ? "When students contact you or make rent bargain offers, new messages will appear here."
                                : "When managers respond to your messages or offers, updates will appear here.",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Filter out accidental self-chats
                final chats = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (isManager && data['studentId'] == user.uid) return false;
                  return true;
                }).toList();

                if (chats.isEmpty) {
                  return Center(
                    child: Text("No messages yet", style: TextStyle(color: Colors.grey.shade500)),
                  );
                }

                // Sort in memory by lastMessageTime descending (to avoid composite index requirement)
                chats.sort((a, b) {
                  final aTime = (a.data() as Map<String, dynamic>)['lastMessageTime'] as Timestamp?;
                  final bTime = (b.data() as Map<String, dynamic>)['lastMessageTime'] as Timestamp?;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: chats.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final chatDoc = chats[index];
                    final data = chatDoc.data() as Map<String, dynamic>;

                    final studentName = data['studentName']?.toString() ?? 'Student';
                    final managerName = data['managerName']?.toString() ?? 'Hostel Manager';
                    final hostelName = data['hostelName']?.toString() ?? 'Hostel';
                    final lastMsg = data['lastMessage']?.toString() ?? 'Chat started';
                    final lastTime = data['lastMessageTime'];
                    final timeStr = _formatTimestamp(lastTime);

                    final isUnread = isManager
                        ? (data['unreadByManager'] == true ||
                            (data['unreadByManager'] == null &&
                                data['lastSenderId'] != null &&
                                data['lastSenderId'] != user.uid))
                        : (data['unreadByStudent'] == true ||
                            (data['unreadByStudent'] == null &&
                                data['lastSenderId'] != null &&
                                data['lastSenderId'] != user.uid));

                    final title = isManager ? studentName : hostelName;
                    final subtitlePrefix = isManager ? "🏫 $hostelName" : "👤 $managerName";

                    return Material(
                      color: isUnread ? Colors.blue.shade50.withValues(alpha: 0.6) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      elevation: isUnread ? 2 : 1,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          // Clear unread flag
                          FirebaseFirestore.instance.collection('chats').doc(chatDoc.id).update({
                            isManager ? 'unreadByManager' : 'unreadByStudent': false,
                          }).catchError((_) {});

                          // Close notifications bottom sheet
                          Navigator.pop(context);

                          // Open chatbox
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                chatId: chatDoc.id,
                                hostelId: data['hostelId']?.toString() ?? '',
                                hostelName: hostelName,
                                managerId: data['managerId']?.toString() ?? '',
                                studentId: data['studentId']?.toString(),
                                originalPrice: (data['originalPrice'] as num?)?.toInt() ?? 0,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Avatar
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: isUnread
                                    ? Colors.blue.shade600
                                    : (isManager ? Colors.indigo.shade100 : Colors.teal.shade100),
                                child: Text(
                                  title.isNotEmpty ? title[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: isUnread
                                        ? Colors.white
                                        : (isManager ? Colors.indigo.shade800 : Colors.teal.shade800),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Text content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: TextStyle(
                                              fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                              fontSize: 15,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          timeStr,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isUnread ? Colors.blue.shade700 : Colors.grey.shade500,
                                            fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      subtitlePrefix,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: isUnread ? Colors.blue.shade800 : Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      lastMsg,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                                        color: isUnread ? Colors.black87 : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Unread badge dot
                              if (isUnread) ...[
                                const SizedBox(width: 8),
                                Container(
                                  margin: const EdgeInsets.only(top: 14),
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade600,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.shade300,
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
