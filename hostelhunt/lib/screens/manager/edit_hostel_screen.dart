import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EditHostelScreen extends StatefulWidget {

  final QueryDocumentSnapshot hostel;

  const EditHostelScreen({
    super.key,
    required this.hostel,
  });

  @override
  State<EditHostelScreen> createState() =>
      _EditHostelScreenState();
}

class _EditHostelScreenState
    extends State<EditHostelScreen> {

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Edit Hostel"),
      ),

      body: Center(

        child: Text(

          widget.hostel["hostelName"],

          style: const TextStyle(
            fontSize: 24,
          ),

        ),

      ),

    );

  }

}