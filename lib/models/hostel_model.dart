class HostelModel {
  String? hostelId;
  String hostelName;
  String ownerName;
  String ownerPhone;
  String collegeName;
  String address;
  double latitude;
  double longitude;
  int price; // Base price (includes Food, Bed, WiFi)
  int deposit;
  int vacancy;
  double rating;
  List<String> facilities;
  List<String> images;
  String description;
  Map<String, int> facilityCosts; // Extra costs for optional facilities
  String hostelType; // "Boys", "Girls", "Co-Ed"
  double distanceFromCollege; // in kms
  String? managerId;

  HostelModel({
    this.hostelId,
    required this.hostelName,
    required this.ownerName,
    required this.ownerPhone,
    required this.collegeName,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.price,
    required this.deposit,
    required this.vacancy,
    required this.rating,
    required this.facilities,
    required this.images,
    required this.description,
    this.facilityCosts = const {},
    this.hostelType = "Co-Ed",
    this.distanceFromCollege = 0.0,
    this.managerId,
  });

  /// Total price = Base price + sum of all extra facility costs
  int get totalPrice =>
      price + facilityCosts.values.fold(0, (sum, cost) => sum + cost);

  Map<String, dynamic> toMap() {
    return {
      "hostelName": hostelName,
      "ownerName": ownerName,
      "ownerPhone": ownerPhone,
      "collegeName": collegeName,
      "address": address,
      "latitude": latitude,
      "longitude": longitude,
      "price": price,
      "deposit": deposit,
      "vacancy": vacancy,
      "rating": rating,
      "facilities": facilities,
      "images": images,
      "description": description,
      "facilityCosts": facilityCosts,
      "hostelType": hostelType,
      "distanceFromCollege": distanceFromCollege,
      "managerId": managerId,
    };
  }

  factory HostelModel.fromMap(
      Map<String, dynamic> map,
      String id,
      ) {
    // Parse facilityCosts safely
    Map<String, int> parsedCosts = {};
    if (map["facilityCosts"] != null) {
      (map["facilityCosts"] as Map<String, dynamic>).forEach((key, value) {
        parsedCosts[key] = (value as num).toInt();
      });
    }

    return HostelModel(
      hostelId: id,
      hostelName: map["hostelName"],
      ownerName: map["ownerName"],
      ownerPhone: map["ownerPhone"],
      collegeName: map["collegeName"],
      address: map["address"],
      latitude: (map["latitude"] as num).toDouble(),
      longitude: (map["longitude"] as num).toDouble(),
      price: map["price"],
      deposit: map["deposit"],
      vacancy: map["vacancy"],
      rating: (map["rating"] as num).toDouble(),
      facilities: List<String>.from(map["facilities"]),
      images: List<String>.from(map["images"]),
      description: map["description"],
      facilityCosts: parsedCosts,
      hostelType: map["hostelType"] ?? "Co-Ed",
      distanceFromCollege: (map["distanceFromCollege"] as num?)?.toDouble() ?? 0.0,
      managerId: map["managerId"],
    );
  }
}