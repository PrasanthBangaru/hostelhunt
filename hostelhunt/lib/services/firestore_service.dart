import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/hostel_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Add Hostel
  Future<void> addHostel(HostelModel hostel) async {
    await _firestore.collection("hostels").add(hostel.toMap());
  }

  /// Get All Hostels
  Stream<QuerySnapshot> getHostels() {
    return _firestore.collection("hostels").snapshots();
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