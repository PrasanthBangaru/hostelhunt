import 'package:flutter/material.dart';
import '../../models/hostel_model.dart';
import '../../services/firestore_service.dart';

class AddHostelScreen extends StatefulWidget {
  const AddHostelScreen({super.key});

  @override
  State<AddHostelScreen> createState() => _AddHostelScreenState();
}

class _AddHostelScreenState extends State<AddHostelScreen> {
  final hostelName = TextEditingController();
  final ownerName = TextEditingController();
  final ownerPhone = TextEditingController();
  final college = TextEditingController();
  final address = TextEditingController();
  final price = TextEditingController();
  final deposit = TextEditingController();
  final vacancy = TextEditingController();
  final description = TextEditingController();

  final firestore = FirestoreService();

  // Basic facilities always included in base price
  final List<String> basicFacilities = ['Bed', 'Food', 'WiFi'];

  // Extra facilities with default additional costs
  final Map<String, int> defaultExtraCosts = {
    'AC': 2000,
    'Fridge': 500,
    'Laundry': 300,
    'Parking': 200,
  };

  // Which extra facilities are selected by the manager
  Map<String, bool> selectedExtras = {
    'AC': false,
    'Fridge': false,
    'Laundry': false,
    'Parking': false,
  };

  // Editable costs for each extra facility
  Map<String, TextEditingController> extraCostControllers = {};

  @override
  void initState() {
    super.initState();
    // Initialize editable cost controllers with default values
    defaultExtraCosts.forEach((facility, cost) {
      extraCostControllers[facility] = TextEditingController(text: cost.toString());
    });
    // Listen to base price changes to update total
    price.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    hostelName.dispose();
    ownerName.dispose();
    ownerPhone.dispose();
    college.dispose();
    address.dispose();
    price.dispose();
    deposit.dispose();
    vacancy.dispose();
    description.dispose();
    for (var c in extraCostControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Calculate live total price
  int get _totalPrice {
    int base = int.tryParse(price.text) ?? 0;
    int extras = 0;
    selectedExtras.forEach((facility, isSelected) {
      if (isSelected) {
        extras += int.tryParse(extraCostControllers[facility]?.text ?? '0') ?? 0;
      }
    });
    return base + extras;
  }

  /// Build the facilityCosts map from selected extras
  Map<String, int> get _facilityCosts {
    Map<String, int> costs = {};
    selectedExtras.forEach((facility, isSelected) {
      if (isSelected) {
        costs[facility] = int.tryParse(extraCostControllers[facility]?.text ?? '0') ?? 0;
      }
    });
    return costs;
  }

  /// All selected facilities (basic + selected extras)
  List<String> get _allFacilities {
    List<String> all = [...basicFacilities];
    selectedExtras.forEach((facility, isSelected) {
      if (isSelected) all.add(facility);
    });
    return all;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Hostel"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            TextField(
              controller: hostelName,
              decoration: const InputDecoration(labelText: "Hostel Name"),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: ownerName,
              decoration: const InputDecoration(labelText: "Owner Name"),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: ownerPhone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: "Owner Phone"),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: college,
              decoration: const InputDecoration(labelText: "Nearby College"),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: address,
              decoration: const InputDecoration(labelText: "Address"),
            ),
            const SizedBox(height: 15),

            // Base Price
            TextField(
              controller: price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Base Price (₹/month)",
                helperText: "Includes: Bed, Food, WiFi",
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: deposit,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Deposit (₹)"),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: vacancy,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Vacancy"),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: description,
              maxLines: 4,
              decoration: const InputDecoration(labelText: "Description"),
            ),

            const SizedBox(height: 25),

            // ── Basic Facilities ──────────────────────────────
            const Text(
              "Basic Facilities",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              "Included in base price",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: basicFacilities.map((f) => Chip(
                label: Text(f),
                avatar: const Icon(Icons.check_circle, color: Colors.green, size: 18),
                backgroundColor: Colors.green.shade50,
              )).toList(),
            ),

            const SizedBox(height: 25),

            // ── Extra Facilities ──────────────────────────────
            const Text(
              "Extra Facilities",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              "Select and set extra price for each",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 10),

            ...selectedExtras.keys.map((facility) {
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Checkbox(
                        value: selectedExtras[facility],
                        onChanged: (val) {
                          setState(() {
                            selectedExtras[facility] = val ?? false;
                          });
                        },
                      ),
                      Expanded(
                        child: Text(
                          facility,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (selectedExtras[facility] == true) ...[
                        const Text(
                          "+₹ ",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: extraCostControllers[facility],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const Text(
                          "/mo",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ] else
                        Text(
                          "+₹${defaultExtraCosts[facility]}",
                          style: const TextStyle(color: Colors.grey),
                        ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 25),

            // ── Live Price Summary ────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Price Summary",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Base Price (Bed + Food + WiFi)"),
                      Text("₹${price.text.isEmpty ? 0 : price.text}"),
                    ],
                  ),
                  ...selectedExtras.entries
                      .where((e) => e.value)
                      .map((e) => Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("${e.key} (extra)"),
                              Text(
                                "+₹${extraCostControllers[e.key]?.text ?? 0}",
                                style: const TextStyle(color: Colors.orange),
                              ),
                            ],
                          )),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Total Price / month",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "₹$_totalPrice",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  HostelModel hostel = HostelModel(
                    hostelName: hostelName.text,
                    ownerName: ownerName.text,
                    ownerPhone: ownerPhone.text,
                    collegeName: college.text,
                    address: address.text,
                    latitude: 0,
                    longitude: 0,
                    price: int.tryParse(price.text) ?? 0,
                    deposit: int.tryParse(deposit.text) ?? 0,
                    vacancy: int.tryParse(vacancy.text) ?? 0,
                    rating: 0,
                    facilities: _allFacilities,
                    images: [],
                    description: description.text,
                    facilityCosts: _facilityCosts,
                  );

                  await firestore.addHostel(hostel);

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Hostel Added Successfully"),
                    ),
                  );

                  Navigator.pop(context);
                },
                child: const Text("Save Hostel"),
              ),
            ),

          ],
        ),
      ),
    );
  }
}