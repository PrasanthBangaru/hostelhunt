import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String? reviewId;
  final String hostelId;
  final String studentName;
  final String studentId;
  final double rating;
  final String comment;
  final DateTime timestamp;
  final String sentiment; // 'positive', 'neutral', 'negative'
  final double sentimentScore; // Value between 0.0 and 1.0

  ReviewModel({
    this.reviewId,
    required this.hostelId,
    required this.studentName,
    required this.studentId,
    required this.rating,
    required this.comment,
    required this.timestamp,
    this.sentiment = 'neutral',
    this.sentimentScore = 0.5,
  });

  Map<String, dynamic> toMap() {
    return {
      'hostelId': hostelId,
      'studentName': studentName,
      'studentId': studentId,
      'rating': rating,
      'comment': comment,
      'timestamp': Timestamp.fromDate(timestamp),
      'sentiment': sentiment,
      'sentimentScore': sentimentScore,
    };
  }

  factory ReviewModel.fromMap(Map<String, dynamic> map, String id) {
    return ReviewModel(
      reviewId: id,
      hostelId: map['hostelId'] ?? '',
      studentName: map['studentName'] ?? 'Anonymous',
      studentId: map['studentId'] ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      comment: map['comment'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sentiment: map['sentiment'] ?? 'neutral',
      sentimentScore: (map['sentimentScore'] as num?)?.toDouble() ?? 0.5,
    );
  }
}
