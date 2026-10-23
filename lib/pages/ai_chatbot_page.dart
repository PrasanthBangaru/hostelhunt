import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class _HostelData {
  final String hostelId;
  final String hostelName;
  final String hostelType;
  final int price;
  final int vacancy;
  final double rating;
  final double distanceFromCollege;
  final List<String> facilities;
  final String address;

  _HostelData({
    required this.hostelId,
    required this.hostelName,
    required this.hostelType,
    required this.price,
    required this.vacancy,
    required this.rating,
    required this.distanceFromCollege,
    required this.facilities,
    required this.address,
  });

  factory _HostelData.fromMap(Map<String, dynamic> map, String id) {
    return _HostelData(
      hostelId: id,
      hostelName: map['hostelName'] ?? '',
      hostelType: map['hostelType'] ?? 'Co-Ed',
      price: (map['price'] as num?)?.toInt() ?? 0,
      vacancy: (map['vacancy'] as num?)?.toInt() ?? 0,
      rating: (map['rating'] as num?)?.toDouble() ?? 4.0,
      distanceFromCollege: (map['distanceFromCollege'] as num?)?.toDouble() ?? 1.0,
      facilities: List<String>.from(map['facilities'] ?? []),
      address: map['address'] ?? '',
    );
  }
}

class _AIService {
  static final _AIService _instance = _AIService._internal();
  factory _AIService() => _instance;
  _AIService._internal();

  String _apiKey = const String.fromEnvironment('GEMINI_API_KEY');

  void setApiKey(String key) {
    _apiKey = key;
  }

  String get apiKey => _apiKey;
  bool get hasApiKey => _apiKey.isNotEmpty && _apiKey != 'YOUR_GEMINI_KEY';

  GenerativeModel? _getModel({String modelName = 'gemini-1.5-flash'}) {
    if (!hasApiKey) return null;
    return GenerativeModel(
      model: modelName,
      apiKey: _apiKey,
    );
  }

  Future<String> getChatResponse(
    String message,
    List<_HostelData> hostels,
    List<Map<String, String>> history,
  ) async {
    final model = _getModel();
    if (model != null) {
      try {
        final hostelData = hostels.map((h) => {
          'id': h.hostelId,
          'name': h.hostelName,
          'type': h.hostelType,
          'price': h.price,
          'vacancy': h.vacancy,
          'rating': h.rating,
          'distance': h.distanceFromCollege,
          'facilities': h.facilities,
          'address': h.address,
        }).toList();

        final systemInstruction = 'You are HostelHunt AI, a helpful, intelligent guide for students finding hostels. '
            'Here is the live database of hostels:\n${jsonEncode(hostelData)}\n\n'
            'Use this data to answer queries accurately. If asked for recommendations, list matching hostels with details. '
            'Keep your responses friendly, concise, and professional.';

        List<Content> contents = [];
        contents.add(Content.text('System Context: $systemInstruction'));

        for (var turn in history) {
          final isUser = turn['sender'] == 'user';
          contents.add(isUser ? Content.text(turn['text']!) : Content.model([TextPart(turn['text']!)]));
        }

        contents.add(Content.text(message));

        final response = await model.generateContent(contents);
        return response.text ?? 'I could not generate a response. Please check your query.';
      } catch (e) {
        return _fallbackChatResponse(message, hostels);
      }
    } else {
      return _fallbackChatResponse(message, hostels);
    }
  }

  String _fallbackChatResponse(String message, List<_HostelData> hostels) {
    final lowercase = message.toLowerCase();

    if (hostels.isEmpty) {
      return "Hi there! I'm the offline HostelHunt AI. Currently, there are no hostels listed in the system, so I can't recommend any. Please add some hostels first!";
    }

    if (lowercase.contains('cheap') || lowercase.contains('low price') || lowercase.contains('budget')) {
      final sorted = List<_HostelData>.from(hostels)..sort((a, b) => a.price.compareTo(b.price));
      final cheapest = sorted.first;
      return "The most budget-friendly hostel is **${cheapest.hostelName}** at just **₹${cheapest.price}/month**. It's a ${cheapest.hostelType} hostel located ${cheapest.distanceFromCollege} km from campus.";
    }

    if (lowercase.contains('near') || lowercase.contains('close') || lowercase.contains('distance')) {
      final sorted = List<_HostelData>.from(hostels)..sort((a, b) => a.distanceFromCollege.compareTo(b.distanceFromCollege));
      final closest = sorted.first;
      return "The closest hostel to campus is **${closest.hostelName}**, located just **${closest.distanceFromCollege} km** away. Rent is ₹${closest.price}/month.";
    }

    if (lowercase.contains('best') || lowercase.contains('rating') || lowercase.contains('top')) {
      final sorted = List<_HostelData>.from(hostels)..sort((a, b) => b.rating.compareTo(a.rating));
      final top = sorted.first;
      return "The highest-rated hostel is **${top.hostelName}** with a rating of **${top.rating} ★**. It is a ${top.hostelType} hostel priced at ₹${top.price}/month.";
    }

    if (lowercase.contains('boys') || lowercase.contains('boy')) {
      final filtered = hostels.where((h) => h.hostelType.toLowerCase() == 'boys').toList();
      if (filtered.isEmpty) return "Currently, there are no dedicated Boys hostels listed.";
      final names = filtered.map((h) => "**${h.hostelName}** (₹${h.price}/mo)").join(", ");
      return "Here are the available Boys hostels: $names.";
    }

    if (lowercase.contains('girls') || lowercase.contains('girl')) {
      final filtered = hostels.where((h) => h.hostelType.toLowerCase() == 'girls').toList();
      if (filtered.isEmpty) return "Currently, there are no dedicated Girls hostels listed.";
      final names = filtered.map((h) => "**${h.hostelName}** (₹${h.price}/mo)").join(", ");
      return "Here are the available Girls hostels: $names.";
    }

    return "Hello! I am the offline HostelHunt AI assistant. You can ask me questions like:\n"
        "- *What is the cheapest hostel?*\n"
        "- *Which hostel is closest to the college?*\n"
        "- *Show me the highest rated hostels.*\n"
        "- *Show me boys or girls hostels.*";
  }
}

class AIChatbotScreen extends StatefulWidget {
  const AIChatbotScreen({super.key});

  @override
  State<AIChatbotScreen> createState() => _AIChatbotScreenState();
}

class _AIChatbotScreenState extends State<AIChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];

  List<_HostelData> _hostels = [];
  bool _isLoadingHostels = true;
  bool _isTyping = false;

  final TextEditingController _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _apiKeyController.text = _AIService().apiKey;
    _fetchHostels();
    _messages.add({
      'sender': 'ai',
      'text': "Hi! I am your AI Hostel Assistant. 🤖\n\nI can help you find hostels based on price, proximity to college, amenities, or reviews. How can I help you today?",
    });
  }

  Future<void> _fetchHostels() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('hostels').get();
      if (mounted) {
        setState(() {
          _hostels = snap.docs.map((doc) => _HostelData.fromMap(doc.data(), doc.id)).toList();
          _isLoadingHostels = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingHostels = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    _messageController.clear();
    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final response = await _AIService().getChatResponse(
        text,
        _hostels,
        _messages.sublist(0, _messages.length - 1),
      );

      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add({'sender': 'ai', 'text': response});
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add({
            'sender': 'ai',
            'text': "Oops! I encountered an error communicating with the AI backend: $e"
          });
        });
      }
    }
    _scrollToBottom();
  }

  void _showApiKeyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.vpn_key, color: Colors.blue),
            SizedBox(width: 10),
            Text("Gemini API Key Setup"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "To unlock real-time Gemini AI capabilities (advanced recommendations, chatbot parsing, sentiment scoring), enter your API Key below.",
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                labelText: "Gemini API Key",
                hintText: "AIzaSy...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 10),
            const Text(
              "Don't have a key? I'll auto-fallback to high-fidelity offline heuristic calculations!",
              style: TextStyle(color: Colors.blue, fontSize: 12, decoration: TextDecoration.underline),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              _AIService().setApiKey(_apiKeyController.text.trim());
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _AIService().hasApiKey
                        ? 'Gemini API Key updated successfully!'
                        : 'Switched to offline simulation mode.',
                  ),
                ),
              );
              setState(() {});
            },
            child: const Text("Save Key"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.blueAccent,
              child: Icon(Icons.psychology, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("AI Hostel Finder", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(
                  _AIService().hasApiKey ? "● Online (Gemini)" : "● Offline Simulation",
                  style: TextStyle(
                    fontSize: 11,
                    color: _AIService().hasApiKey ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: "AI Key Setup",
            onPressed: _showApiKeyDialog,
          ),
        ],
      ),
      body: _isLoadingHostels
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!_AIService().hasApiKey)
                  Container(
                    width: double.infinity,
                    color: Colors.orange.shade50,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange.shade800, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Running in Offline Simulation mode. Tap the settings gear to enter a Gemini API Key.",
                            style: TextStyle(color: Colors.orange.shade900, fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),

                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return _buildTypingIndicator();
                      }
                      final msg = _messages[index];
                      final isAI = msg['sender'] == 'ai';
                      return _buildMessageBubble(msg['text'] ?? '', isAI);
                    },
                  ),
                ),

                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _buildSuggestChip("💰 What is the cheapest hostel?"),
                      _buildSuggestChip("📍 Show hostels closest to campus"),
                      _buildSuggestChip("★ Show highest rated hostels"),
                      _buildSuggestChip("👦 Boys hostels"),
                      _buildSuggestChip("👧 Girls hostels"),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -1)),
                    ],
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: "Ask about hostels, prices, distances...",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              fillColor: Colors.grey.shade100,
                              filled: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            ),
                            textInputAction: TextInputAction.send,
                            onSubmitted: _sendMessage,
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: Colors.blue,
                          radius: 22,
                          child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.white, size: 18),
                            onPressed: () => _sendMessage(_messageController.text),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSuggestChip(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        onPressed: () => _sendMessage(label.replaceAll(RegExp(r'[^\w\s\?]'), '').trim()),
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isAI) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: isAI ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAI) ...[
            const CircleAvatar(
              backgroundColor: Colors.blueAccent,
              radius: 16,
              child: Icon(Icons.psychology, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isAI ? Colors.white : Colors.blue.shade600,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isAI ? 4 : 16),
                  bottomRight: Radius.circular(isAI ? 16 : 4),
                ),
                boxShadow: isAI
                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                    : [],
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isAI ? Colors.black87 : Colors.white,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
            ),
          ),
          if (!isAI) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              backgroundColor: Colors.grey,
              radius: 16,
              child: Icon(Icons.person, color: Colors.white, size: 16),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Colors.blueAccent,
            radius: 16,
            child: Icon(Icons.psychology, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 3),
                _buildDot(1),
                const SizedBox(width: 3),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 150)),
      builder: (context, value, child) {
        return Opacity(
          opacity: 0.3 + (value * 0.7),
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
