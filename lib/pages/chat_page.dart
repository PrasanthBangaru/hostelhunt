import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatScreen extends StatefulWidget {
  final String hostelId;
  final String hostelName;
  final String managerId;
  final int originalPrice;
  final String? studentId; // null when student opens (uses current user)

  const ChatScreen({
    super.key,
    required this.hostelId,
    required this.hostelName,
    required this.managerId,
    required this.originalPrice,
    this.studentId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late String chatId;
  bool _isLoading = true;

  String _dealStatus = 'none';
  int? _currentOfferPrice;

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser;
    if (user != null) {
      // Build unique chat room ID — always studentId_managerId_hostelId
      final studentId = widget.studentId ?? user.uid;
      chatId = "${studentId}_${widget.managerId}_${widget.hostelId}";
      _ensureChatDocExists().then((_) {
        if (mounted) setState(() => _isLoading = false);
      });

      FirebaseFirestore.instance.collection('chats').doc(chatId).snapshots().listen((snap) {
        if (snap.exists && mounted) {
          final data = snap.data() as Map<String, dynamic>;
          setState(() {
            _dealStatus = data['dealStatus'] ?? 'none';
            _currentOfferPrice = data['currentOfferPrice'] as int?;
          });
        }
      });
    }
  }

  Future<void> _ensureChatDocExists() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
    final docSnap = await docRef.get();

    if (!docSnap.exists) {
      String studentName = "Student";
      String managerName = "Manager";

      try {
        final studentDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (studentDoc.exists) {
          studentName = studentDoc.data()?['name'] ?? "Student";
        }
      } catch (_) {}

      try {
        final managerDoc = await FirebaseFirestore.instance.collection('users').doc(widget.managerId).get();
        if (managerDoc.exists) {
          managerName = managerDoc.data()?['name'] ?? "Manager";
        }
      } catch (_) {}

      await docRef.set({
        'chatId': chatId,
        'studentId': user.uid,
        'studentName': studentName,
        'managerId': widget.managerId,
        'managerName': managerName,
        'hostelId': widget.hostelId,
        'hostelName': widget.hostelName,
        'lastMessage': 'Chat started',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'originalPrice': widget.originalPrice,
        'currentOfferPrice': null,
        'offerSenderId': null,
        'dealStatus': 'none',
      });
    }
  }

  Future<void> _sendMessage(String text, {String type = 'text', int? offerPrice}) async {
    if (text.trim().isEmpty && offerPrice == null) return;
    final user = _auth.currentUser;
    if (user == null) return;

    String senderName = "User";
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        senderName = userDoc.data()?['name'] ?? "User";
      }
    } catch (_) {}

    final msgData = {
      'messageId': FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').doc().id,
      'senderId': user.uid,
      'senderName': senderName,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'messageType': type,
      'offerPrice': offerPrice,
    };

    final batch = FirebaseFirestore.instance.batch();

    // Add message
    final msgRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(msgData['messageId'] as String);
    batch.set(msgRef, msgData);

    // Update last message
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
    Map<String, dynamic> updateData = {
      'lastMessage': type == 'offer'
          ? "💰 Offer proposed: ₹$offerPrice"
          : type == 'offer_accepted'
              ? "🎉 Deal closed: ₹$offerPrice"
              : type == 'offer_rejected'
                  ? "❌ Offer declined"
                  : text,
      'lastMessageTime': FieldValue.serverTimestamp(),
    };

    if (type == 'offer') {
      updateData['dealStatus'] = 'offered';
      updateData['currentOfferPrice'] = offerPrice;
      updateData['offerSenderId'] = user.uid;
    } else if (type == 'offer_accepted') {
      updateData['dealStatus'] = 'deal_closed';
    } else if (type == 'offer_rejected') {
      updateData['dealStatus'] = 'deal_rejected';
      updateData['currentOfferPrice'] = null;
      updateData['offerSenderId'] = null;
    }

    batch.update(chatRef, updateData);

    await batch.commit();
    _messageController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showOfferBottomSheet() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  "💰 Propose Bargain Price",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  "Original Rent: ₹${widget.originalPrice}/month",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: "Your Offer Price",
                    prefixText: "₹ ",
                    hintText: "Enter amount",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    final price = int.tryParse(controller.text.trim());
                    if (price == null || price <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please enter a valid price")),
                      );
                      return;
                    }
                    Navigator.pop(context);
                    _sendMessage(
                      "Proposing offer: ₹$price/mo",
                      type: 'offer',
                      offerPrice: price,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text("Submit Offer", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = _auth.currentUser;
    final isManager = user?.uid == widget.managerId;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(widget.hostelName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(isManager ? "Student Negotiations" : "Hostel Manager", style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Negotiation Details"),
                  content: Text("Original price listed: ₹${widget.originalPrice}/month.\nYou can propose bargaining prices back and forth here."),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Bargaining status widget
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('chats').doc(chatId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const SizedBox.shrink();
              }
              final data = snapshot.data!.data() as Map<String, dynamic>;
              final dealStatus = data['dealStatus'] ?? 'none';
              final currentOfferPrice = data['currentOfferPrice'] as int?;
              final offerSenderId = data['offerSenderId'] as String?;

              if (dealStatus == 'offered' && currentOfferPrice != null) {
                final wasSentByMe = offerSenderId == user?.uid;
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border(bottom: BorderSide(color: Colors.orange.shade200)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.monetization_on, color: Colors.orange.shade700, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Active Offer: ₹$currentOfferPrice/mo",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            Text(
                              wasSentByMe ? "Waiting for response..." : "Review and respond below",
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      if (!wasSentByMe) ...[
                        TextButton.icon(
                          onPressed: () {
                            _sendMessage("Accepted deal at ₹$currentOfferPrice/mo", type: 'offer_accepted', offerPrice: currentOfferPrice);
                          },
                          icon: const Icon(Icons.check_circle, color: Colors.green, size: 18),
                          label: const Text("Accept", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            _sendMessage("Declined offer", type: 'offer_rejected', offerPrice: currentOfferPrice);
                          },
                          icon: const Icon(Icons.cancel, color: Colors.red, size: 18),
                          label: const Text("Decline", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ),
                      ] else ...[
                        TextButton.icon(
                          onPressed: () {
                            _sendMessage("Withdrew offer", type: 'offer_rejected', offerPrice: currentOfferPrice);
                          },
                          icon: const Icon(Icons.undo, color: Colors.blueGrey, size: 18),
                          label: const Text("Withdraw", style: TextStyle(color: Colors.blueGrey)),
                        ),
                      ],
                    ],
                  ),
                );
              } else if (dealStatus == 'deal_closed' && currentOfferPrice != null) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.green.shade50,
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "🎉 Deal Closed at ₹$currentOfferPrice/month!",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // Messages list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
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
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text("No messages yet. Propose your rent offer!", style: TextStyle(color: Colors.black45)),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data!.docs;
                _scrollToBottom();

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data() as Map<String, dynamic>;
                    final senderId = data['senderId'] ?? '';
                    final text = data['text'] ?? '';
                    final type = data['messageType'] ?? 'text';
                    final offerPrice = data['offerPrice'] as int?;
                    final isMe = senderId == user?.uid;

                    if (type == 'offer') {
                      return _buildOfferMessage(isMe, offerPrice ?? 0, data['senderName'] ?? 'Someone');
                    } else if (type == 'offer_accepted') {
                      return _buildDealClosedMessage(offerPrice ?? 0);
                    } else if (type == 'offer_rejected') {
                      return _buildDealRejectedMessage(data['senderName'] ?? 'Someone');
                    }

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blueAccent : Colors.grey.shade100,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMe ? 16 : 4),
                            bottomRight: Radius.circular(isMe ? 4 : 16),
                          ),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Text(
                                data['senderName'] ?? 'Manager',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              text,
                              style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 14),
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

          // Message input & Offer options
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -2))
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Bargain Offer Action Button
                  IconButton(
                    icon: Icon(Icons.monetization_on_outlined, color: Colors.orange.shade700, size: 30),
                    tooltip: "Propose bargaining price",
                    onPressed: _showOfferBottomSheet,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: "Type a message...",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      onSubmitted: (val) => _sendMessage(val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.blueAccent),
                    onPressed: () {
                      final val = _messageController.text;
                      _sendMessage(val);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferMessage(bool isMe, int price, String senderName) {
    final showActionButtons = _dealStatus == 'offered' &&
        _currentOfferPrice == price &&
        !isMe;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          border: Border.all(color: Colors.orange.shade200),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.monetization_on, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 6),
                Text(
                  isMe ? "You proposed an offer!" : "$senderName proposed an offer",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "₹$price / month",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
            ),
            const SizedBox(height: 2),
            Text(
              "Original listed rent: ₹${widget.originalPrice}/mo",
              style: const TextStyle(fontSize: 11, color: Colors.black45),
            ),
            if (showActionButtons) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: Colors.orangeAccent),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      _sendMessage("Accepted deal at ₹$price/mo", type: 'offer_accepted', offerPrice: price);
                    },
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text("Accept Offer"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(120, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      _sendMessage("Declined offer", type: 'offer_rejected', offerPrice: price);
                    },
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text("Decline"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(120, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDealClosedMessage(int price) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          border: Border.all(color: Colors.green.shade200),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Icon(Icons.celebration, color: Colors.green, size: 36),
            const SizedBox(height: 6),
            const Text("🎉 Deal Closed Successfully!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              "Final Agreed rent: ₹$price/month",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDealRejectedMessage(String senderName) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          "❌ Offer declined by $senderName",
          style: TextStyle(color: Colors.red.shade800, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

typedef ChatPage = ChatScreen;
