import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/hostel_model.dart';
import '../../services/ai_service.dart';

class AIChatbotScreen extends StatefulWidget {
  const AIChatbotScreen({super.key});

  @override
  State<AIChatbotScreen> createState() => _AIChatbotScreenState();
}

class _AIChatbotScreenState extends State<AIChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  
  List<HostelModel> _hostels = [];
  bool _isLoadingHostels = true;
  bool _isTyping = false;
  
  // Custom temporary key input for session testing
  final TextEditingController _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _apiKeyController.text = AIService().apiKey;
    _fetchHostels();
    // Welcome message
    _messages.add({
      'sender': 'ai',
      'text': "Hi! I am your AI Hostel Assistant. 🤖\n\nI can help you find hostels based on price, proximity to college, amenities, or reviews. How can I help you today?",
    });
  }

  Future<void> _fetchHostels() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('hostels').get();
      setState(() {
        _hostels = snap.docs.map((doc) => HostelModel.fromMap(doc.data(), doc.id)).toList();
        _isLoadingHostels = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingHostels = false;
      });
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

    // Call AI Service
    try {
      final response = await AIService().getChatResponse(
        text,
        _hostels,
        _messages.sublist(0, _messages.length - 1), // History
      );
      
      setState(() {
        _isTyping = false;
        _messages.add({'sender': 'ai', 'text': response});
      });
    } catch (e) {
      setState(() {
        _isTyping = false;
        _messages.add({
          'sender': 'ai',
          'text': "Oops! I encountered an error communicating with the AI backend: $e"
        });
      });
    }
    _scrollToBottom();
  }

  void _showApiKeyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
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
            GestureDetector(
              onTap: () {
                // Link to get API Key
              },
              child: const Text(
                "Don't have a key? I'll auto-fallback to high-fidelity offline heuristic calculations!",
                style: TextStyle(color: Colors.blue, fontSize: 12, decoration: TextDecoration.underline),
              ),
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
              AIService().setApiKey(_apiKeyController.text.trim());
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AIService().hasApiKey 
                        ? 'Gemini API Key updated successfully!' 
                        : 'Switched to offline simulation mode.',
                  ),
                ),
              );
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
                  AIService().hasApiKey ? "● Online (Gemini)" : "● Offline Simulation",
                  style: TextStyle(
                    fontSize: 11,
                    color: AIService().hasApiKey ? Colors.green : Colors.orange,
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
                // Warning if using offline mode
                if (!AIService().hasApiKey)
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

                // Chat Messages List
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

                // Quick Suggestion Chips
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

                // Message input panel
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
