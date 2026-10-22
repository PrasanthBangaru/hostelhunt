import 'dart:convert';
import 'dart:math';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/hostel_model.dart';

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  // Configurable API key (can be input by user in the chatbot UI or read from environment)
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

  /// 1. Sentiment Analysis
  Future<Map<String, dynamic>> analyzeSentiment(String comment) async {
    final model = _getModel();
    if (model != null) {
      try {
        final prompt = 'Analyze the sentiment of this review comment for a hostel: "$comment". '
            'Reply ONLY in JSON format: {"sentiment": "positive" | "neutral" | "negative", "score": 0.0 to 1.0}';
        
        final response = await model.generateContent([Content.text(prompt)]);
        final cleanText = response.text?.trim() 
            .replaceAll('```json', '')
            .replaceAll('```', '') ?? '';
            
        final decoded = jsonDecode(cleanText);
        return {
          'sentiment': decoded['sentiment'] ?? 'neutral',
          'score': (decoded['score'] as num?)?.toDouble() ?? 0.5,
        };
      } catch (e) {
        // Fallback to local heuristic if network/API fails
        return _fallbackSentimentAnalysis(comment);
      }
    } else {
      return _fallbackSentimentAnalysis(comment);
    }
  }

  Map<String, dynamic> _fallbackSentimentAnalysis(String comment) {
    final lowercase = comment.toLowerCase();
    
    // Simple Lexicon matching
    final positiveWords = ['good', 'great', 'nice', 'clean', 'friendly', 'best', 'love', 'comfortable', 'awesome', 'excellent', 'peaceful', 'safety', 'safe', 'worth', 'well', 'perfect'];
    final negativeWords = ['bad', 'dirty', 'noisy', 'rude', 'worst', 'hate', 'uncomfortable', 'expensive', 'crowded', 'smell', 'poor', 'slow', 'waste', 'regret', 'unsafe', 'dusty'];
    
    int posCount = 0;
    int negCount = 0;
    
    for (var word in positiveWords) {
      if (lowercase.contains(word)) posCount++;
    }
    for (var word in negativeWords) {
      if (lowercase.contains(word)) negCount++;
    }
    
    if (posCount > negCount) {
      double score = 0.5 + (posCount - negCount) * 0.1;
      return {'sentiment': 'positive', 'score': score.clamp(0.6, 1.0)};
    } else if (negCount > posCount) {
      double score = 0.5 - (negCount - posCount) * 0.1;
      return {'sentiment': 'negative', 'score': score.clamp(0.0, 0.4)};
    } else {
      return {'sentiment': 'neutral', 'score': 0.5};
    }
  }

  /// 2. Personalized AI Recommendations
  Future<List<Map<String, dynamic>>> getRecommendations(
    List<HostelModel> hostels, {
    required double maxPrice,
    required String preferredType,
    required double maxDistance,
    required List<String> preferredFacilities,
  }) async {
    // 1. Calculate local similarity match scores first
    List<Map<String, dynamic>> scoredHostels = [];

    for (var hostel in hostels) {
      double score = 100.0;
      List<String> reasons = [];

      // Price match (0-30 points)
      if (hostel.price <= maxPrice) {
        score += 0.0; // stays max
        reasons.add('Fits within your budget of ₹${maxPrice.toInt()}');
      } else {
        double diff = (hostel.price - maxPrice) / maxPrice;
        score -= (diff * 40).clamp(0, 30);
      }

      // Distance match (0-25 points)
      if (hostel.distanceFromCollege <= maxDistance) {
        reasons.add('Close to college (${hostel.distanceFromCollege} km away)');
      } else {
        double diff = (hostel.distanceFromCollege - maxDistance) / maxDistance;
        score -= (diff * 25).clamp(0, 25);
      }

      // Rating (0-15 points)
      score += (hostel.rating / 5.0) * 15;
      if (hostel.rating >= 4.0) {
        reasons.add('Highly rated by other students (${hostel.rating}★)');
      }

      // Type match (0-15 points)
      if (preferredType.toLowerCase() != 'any') {
        if (hostel.hostelType.toLowerCase() == preferredType.toLowerCase()) {
          reasons.add('Matches your preference for a ${hostel.hostelType} hostel');
        } else {
          score -= 15;
        }
      }

      // Facilities match (0-15 points)
      int matchedFacilities = 0;
      for (var f in preferredFacilities) {
        if (hostel.facilities.any((hf) => hf.toLowerCase().contains(f.toLowerCase()))) {
          matchedFacilities++;
        }
      }
      if (preferredFacilities.isNotEmpty) {
        double ratio = matchedFacilities / preferredFacilities.length;
        score += ratio * 15;
        if (matchedFacilities > 0) {
          reasons.add('Has $matchedFacilities of your preferred amenities');
        }
      }

      scoredHostels.add({
        'hostel': hostel,
        'matchScore': score.clamp(0.0, 100.0),
        'reasons': reasons,
      });
    }

    // Sort by descending score
    scoredHostels.sort((a, b) => (b['matchScore'] as double).compareTo(a['matchScore'] as double));

    // 2. If Gemini is available, enrich the recommendation text explanation
    final model = _getModel();
    if (model != null && scoredHostels.isNotEmpty) {
      try {
        final topThree = scoredHostels.take(3).map((sh) => (sh['hostel'] as HostelModel).toMap()).toList();
        final prompt = 'Given these top 3 recommended hostels: ${jsonEncode(topThree)} '
            'and student preferences (max budget: ₹$maxPrice, type: $preferredType, max distance: $maxDistance km, preferred features: $preferredFacilities), '
            'generate a brief, friendly, 2-sentence summary explaining why these are good matches. Use markdown.';
        
        final response = await model.generateContent([Content.text(prompt)]);
        if (response.text != null && response.text!.isNotEmpty) {
          for (int i = 0; i < min(3, scoredHostels.length); i++) {
            scoredHostels[i]['aiReasoning'] = response.text;
          }
        }
      } catch (_) {
        // Keep standard reasons
      }
    }

    return scoredHostels;
  }

  /// 3. AI Chatbot
  Future<String> getChatResponse(
    String message,
    List<HostelModel> hostels,
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

        // Build history contents
        List<Content> contents = [];
        // Add system instruction first in prompt text or use systemInstruction parameter
        // For simplicity with standard sdk:
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

  String _fallbackChatResponse(String message, List<HostelModel> hostels) {
    final lowercase = message.toLowerCase();

    if (hostels.isEmpty) {
      return "Hi there! I'm the offline HostelHunt AI. Currently, there are no hostels listed in the system, so I can't recommend any. Please add some hostels first!";
    }

    // Helper functions
    if (lowercase.contains('cheap') || lowercase.contains('low price') || lowercase.contains('budget')) {
      final sorted = List<HostelModel>.from(hostels)..sort((a, b) => a.price.compareTo(b.price));
      final cheapest = sorted.first;
      return "The most budget-friendly hostel is **${cheapest.hostelName}** at just **₹${cheapest.price}/month**. It's a ${cheapest.hostelType} hostel located ${cheapest.distanceFromCollege} km from campus.";
    }

    if (lowercase.contains('near') || lowercase.contains('close') || lowercase.contains('distance')) {
      final sorted = List<HostelModel>.from(hostels)..sort((a, b) => a.distanceFromCollege.compareTo(b.distanceFromCollege));
      final closest = sorted.first;
      return "The closest hostel to campus is **${closest.hostelName}**, located just **${closest.distanceFromCollege} km** away. Rent is ₹${closest.price}/month.";
    }

    if (lowercase.contains('best') || lowercase.contains('rating') || lowercase.contains('top')) {
      final sorted = List<HostelModel>.from(hostels)..sort((a, b) => b.rating.compareTo(a.rating));
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

    // Default conversational response
    return "Hello! I am the offline HostelHunt AI assistant. You can ask me questions like:\n"
        "- *What is the cheapest hostel?*\n"
        "- *Which hostel is closest to the college?*\n"
        "- *Show me the highest rated hostels.*\n"
        "- *Show me boys or girls hostels.*";
  }
}
