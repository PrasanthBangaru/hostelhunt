import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/hostel_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Add Hostel (saves managerId so we can filter later)
  Future<void> addHostel(HostelModel hostel, {String? managerId}) async {
    final data = hostel.toMap();
    if (managerId != null) data['managerId'] = managerId;
    await _firestore.collection("hostels").add(data);
  }

  /// Get ALL Hostels (used by students)
  Stream<QuerySnapshot> getHostels() {
    return _firestore.collection("hostels").snapshots();
  }

  /// Get only this manager's hostels
  Stream<QuerySnapshot> getMyHostels(String managerId) {
    return _firestore
        .collection("hostels")
        .where('managerId', isEqualTo: managerId)
        .snapshots();
  }

  /// Delete Hostel
  Future<void> deleteHostel(String id) async {
    await _firestore.collection("hostels").doc(id).delete();
  }

  /// Update Hostel
  Future<void> updateHostel(
      String id,
      HostelModel hostel,
      ) async {

    await _firestore
        .collection("hostels")
        .doc(id)
        .update(hostel.toMap());

  }
}