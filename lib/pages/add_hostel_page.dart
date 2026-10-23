import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final distance = TextEditingController();

  String selectedHostelType = "Co-Ed";

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

  double foodRating = 4.6;
  int _selectedMenuDayIndex = 0;

  static const List<String> _weekDays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  final Map<String, Map<String, TextEditingController>> _menuControllers = {};

  static const Map<String, Map<String, String>> _defaultWeeklyMenu = {
    'Monday': {
      'breakfast': 'Idly + Sambar + Chutney',
      'lunch': 'Rice + Dal Tadka + Veg Curry + Curd',
      'dinner': 'Soft Chapathi + Paneer Butter Masala',
      'special': 'Paneer Delight',
    },
    'Tuesday': {
      'breakfast': 'Poori + Aloo Masala',
      'lunch': 'Rice + Tomato Sambar + Bhindi Fry + Buttermilk',
      'dinner': 'Hot Phulka + Mixed Veg Korma',
      'special': 'Home Style Curry',
    },
    'Wednesday': {
      'breakfast': 'Poha / Upma + Peanut Chutney',
      'lunch': 'Jeera Rice + Rajma Masala + Salad',
      'dinner': 'Veg Fried Rice + Veg/Chicken Manchurian',
      'special': '⭐ Indo-Chinese Feast',
    },
    'Thursday': {
      'breakfast': 'Crispy Masala Dosa + Sambar',
      'lunch': 'Rice + Spinach Dal + Raw Banana Fry + Curd',
      'dinner': 'Chapathi + Egg Curry / Paneer Bhurji',
      'special': 'Crispy Dosa Night',
    },
    'Friday': {
      'breakfast': 'Ghee Pongal + Medu Vada + Sambar',
      'lunch': 'Steamed Rice + Chole Masala + Cucumber Raita',
      'dinner': 'Soft Rotis + Mushroom Curry + Gulab Jamun',
      'special': 'Sweet Friday Treat',
    },
    'Saturday': {
      'breakfast': 'Aloo Paratha + Fresh Butter + Curd',
      'lunch': 'South Indian Thali (Rice, Rasam, Dal, Poriyal)',
      'dinner': 'Veg Pulao + Mirchi Ka Salan + Raita',
      'special': 'Pulao Night',
    },
    'Sunday': {
      'breakfast': 'Chole Bhature / Onion Uttapam',
      'lunch': 'Hyderabadi Dum Biryani (Chicken / Paneer) + Raitha',
      'dinner': 'Light Phulka + Yellow Dal Tadka',
      'special': '🔥 Grand Sunday Biryani Feast',
    },
  };

  void _initMenuControllers() {
    _defaultWeeklyMenu.forEach((day, meals) {
      _menuControllers[day] = {
        'breakfast': TextEditingController(text: meals['breakfast']),
        'lunch': TextEditingController(text: meals['lunch']),
        'dinner': TextEditingController(text: meals['dinner']),
        'special': TextEditingController(text: meals['special']),
      };
    });
  }

  void _applyMenuPreset(String preset) {
    setState(() {
      if (preset == 'south') {
        _menuControllers['Monday']!['breakfast']!.text = 'Idly + Sambar + Chutney';
        _menuControllers['Monday']!['lunch']!.text = 'Rice + Sambar + Poriyal + Curd';
        _menuControllers['Monday']!['dinner']!.text = 'Chapathi + Kurma + Rice';
        _menuControllers['Wednesday']!['dinner']!.text = 'Lemon Rice + Curd Rice + Potato Roast';
        _menuControllers['Friday']!['breakfast']!.text = 'Ghee Pongal + Medu Vada + Chutney';
        _menuControllers['Sunday']!['lunch']!.text = 'South Indian Biryani / Thali Special';
      } else if (preset == 'north') {
        _menuControllers['Monday']!['breakfast']!.text = 'Aloo Paratha + Dahi + Pickle';
        _menuControllers['Monday']!['lunch']!.text = 'Rice + Dal Makhani + Paneer';
        _menuControllers['Monday']!['dinner']!.text = 'Roti + Mixed Veg + Jeera Rice';
        _menuControllers['Wednesday']!['lunch']!.text = 'Rajma Chawal + Boondi Raita';
        _menuControllers['Sunday']!['breakfast']!.text = 'Chole Bhature + Lassi';
        _menuControllers['Sunday']!['lunch']!.text = 'Paneer / Chicken Pulao + Raita';
      } else {
        _defaultWeeklyMenu.forEach((day, meals) {
          _menuControllers[day]!['breakfast']!.text = meals['breakfast']!;
          _menuControllers[day]!['lunch']!.text = meals['lunch']!;
          _menuControllers[day]!['dinner']!.text = meals['dinner']!;
          _menuControllers[day]!['special']!.text = meals['special']!;
        });
      }
    });
  }

  Map<String, Map<String, String>> get _foodMenuData {
    Map<String, Map<String, String>> data = {};
    _menuControllers.forEach((day, controllers) {
      data[day] = {
        'breakfast': controllers['breakfast']!.text.trim().isNotEmpty
            ? controllers['breakfast']!.text.trim()
            : 'Idly + Sambar',
        'lunch': controllers['lunch']!.text.trim().isNotEmpty
            ? controllers['lunch']!.text.trim()
            : 'Rice + Curry',
        'dinner': controllers['dinner']!.text.trim().isNotEmpty
            ? controllers['dinner']!.text.trim()
            : 'Chapathi + Paneer',
        'special': controllers['special']!.text.trim(),
      };
    });
    return data;
  }

  @override
  void initState() {
    super.initState();
    // Initialize editable cost controllers with default values
    defaultExtraCosts.forEach((facility, cost) {
      extraCostControllers[facility] = TextEditingController(text: cost.toString());
    });
    _initMenuControllers();
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
    distance.dispose();
    for (var c in extraCostControllers.values) {
      c.dispose();
    }
    for (var dayMap in _menuControllers.values) {
      for (var c in dayMap.values) {
        c.dispose();
      }
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
            DropdownButtonFormField<String>(
              value: selectedHostelType,
              decoration: const InputDecoration(
                labelText: "Hostel Type",
                prefixIcon: Icon(Icons.people),
              ),
              items: ["Boys", "Girls", "Co-Ed"]
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text("$type Hostel"),
                      ))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  selectedHostelType = val ?? "Co-Ed";
                });
              },
            ),
            const SizedBox(height: 15),
            TextField(
              controller: distance,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: "Distance from Nearby College (km)",
                prefixIcon: Icon(Icons.map),
              ),
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

            // 🍽️ Weekly Food Menu & Rating Configuration
            _buildWeeklyFoodMenuEditor(),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  final hostelData = {
                    "hostelName": hostelName.text,
                    "ownerName": ownerName.text,
                    "ownerPhone": ownerPhone.text,
                    "collegeName": college.text,
                    "address": address.text,
                    "latitude": 0.0,
                    "longitude": 0.0,
                    "price": int.tryParse(price.text) ?? 0,
                    "deposit": int.tryParse(deposit.text) ?? 0,
                    "vacancy": int.tryParse(vacancy.text) ?? 0,
                    "rating": 0.0,
                    "facilities": _allFacilities,
                    "images": <String>[],
                    "description": description.text,
                    "facilityCosts": _facilityCosts,
                    "hostelType": selectedHostelType,
                    "distanceFromCollege": double.tryParse(distance.text) ?? 0.0,
                    "foodRating": foodRating,
                    "foodMenu": _foodMenuData,
                    if (uid != null) "managerId": uid,
                  };

                  await FirebaseFirestore.instance.collection("hostels").add(hostelData);

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

  Widget _buildWeeklyFoodMenuEditor() {
    final activeDay = _weekDays[_selectedMenuDayIndex];
    final activeControllers = _menuControllers[activeDay]!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.restaurant_menu, color: Colors.deepOrange, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Weekly Food Menu & Rating",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "Students see your mess menu live in real time",
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Mess Food Rating",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amberAccent, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      "${foodRating.toStringAsFixed(1)} / 5.0",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Slider(
            value: foodRating,
            min: 1.0,
            max: 5.0,
            divisions: 40,
            activeColor: Colors.orange,
            inactiveColor: Colors.orange.shade100,
            label: foodRating.toStringAsFixed(1),
            onChanged: (val) {
              setState(() {
                foodRating = val;
              });
            },
          ),
          const SizedBox(height: 10),

          const Text(
            "⚡ Quick Fill Presets:",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.auto_fix_high, size: 16, color: Colors.deepOrange),
                label: const Text("South Indian Menu"),
                onPressed: () => _applyMenuPreset('south'),
              ),
              ActionChip(
                avatar: const Icon(Icons.auto_fix_high, size: 16, color: Colors.orange),
                label: const Text("North Indian Menu"),
                onPressed: () => _applyMenuPreset('north'),
              ),
              ActionChip(
                avatar: const Icon(Icons.refresh, size: 16, color: Colors.blue),
                label: const Text("Standard Menu"),
                onPressed: () => _applyMenuPreset('standard'),
              ),
            ],
          ),
          const Divider(height: 25),

          Text(
            "Configure Meals for: $activeDay",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _weekDays.length,
              itemBuilder: (context, i) {
                final day = _weekDays[i];
                final isSelected = _selectedMenuDayIndex == i;
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: ChoiceChip(
                    label: Text(day.substring(0, 3)),
                    selected: isSelected,
                    selectedColor: Colors.orange,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _selectedMenuDayIndex = i;
                        });
                      }
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: activeControllers['breakfast'],
            decoration: InputDecoration(
              labelText: "$activeDay Breakfast",
              hintText: "e.g. Idly + Sambar + Chutney",
              prefixIcon: const Icon(Icons.wb_sunny_outlined, color: Colors.amber),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: activeControllers['lunch'],
            decoration: InputDecoration(
              labelText: "$activeDay Lunch",
              hintText: "e.g. Rice + Dal Tadka + Veg Curry + Curd",
              prefixIcon: const Icon(Icons.wb_sunny, color: Colors.orange),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: activeControllers['dinner'],
            decoration: InputDecoration(
              labelText: "$activeDay Dinner",
              hintText: "e.g. Chapathi + Paneer Butter Masala",
              prefixIcon: const Icon(Icons.nightlight_round, color: Colors.indigo),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: activeControllers['special'],
            decoration: InputDecoration(
              labelText: "$activeDay Special (Optional)",
              hintText: "e.g. Chef's Sunday Biryani / Sweet Gulab Jamun",
              prefixIcon: const Icon(Icons.stars, color: Colors.amber),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

typedef AddHostelPage = AddHostelScreen;
