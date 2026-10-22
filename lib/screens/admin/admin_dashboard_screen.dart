import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../manager/edit_hostel_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout Admin"),
        content: const Text("Are you sure you want to log out of the Admin Panel?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _deleteHostel(String hostelId, String hostelName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Hostel Listing"),
        content: Text("Are you sure you want to delete '$hostelName'? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection("hostels").doc(hostelId).delete();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hostel '$hostelName' deleted successfully.")),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error deleting hostel: ${e.toString()}")),
        );
      }
    }
  }

  Future<void> _deleteUser(String userId, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove User Account"),
        content: Text("Are you sure you want to remove user '$userName' from Firestore?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Remove"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection("users").doc(userId).delete();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("User '$userName' removed successfully.")),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error removing user: ${e.toString()}")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.admin_panel_settings, color: Colors.amber, size: 28),
            const SizedBox(width: 8),
            const Text(
              "HostelHunt Admin",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber, width: 1),
              ),
              child: const Text(
                "SUPERUSER",
                style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Logout Admin",
            onPressed: _handleLogout,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.location_city), text: "Manage Hostels"),
            Tab(icon: Icon(Icons.people), text: "Manage Users"),
          ],
        ),
      ),
      body: Column(
        children: [
          // Overview Analytics Summary Header
          _buildAnalyticsHeader(),

          // Tab content (Hostels and Users lists)
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildHostelsTab(),
                _buildUsersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).cardColor,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("hostels").snapshots(),
        builder: (context, hostelsSnapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection("users").snapshots(),
            builder: (context, usersSnapshot) {
              final totalHostels = hostelsSnapshot.data?.docs.length ?? 0;
              final users = usersSnapshot.data?.docs ?? [];
              final totalStudents = users.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data["role"] == "student";
              }).length;
              final totalManagers = users.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data["role"] == "manager";
              }).length;

              return Row(
                children: [
                  _buildStatCard("Total Hostels", "$totalHostels", Icons.hotel, Colors.blue),
                  _buildStatCard("Students", "$totalStudents", Icons.school, Colors.green),
                  _buildStatCard("Managers", "$totalManagers", Icons.business_center, Colors.orange),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHostelsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection("hostels").snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error loading hostels: ${snapshot.error}"));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.hotel_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 12),
                Text("No hostels listed on the platform yet.", style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          padding: const EdgeInsets.all(10),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final hostelId = doc.id;
            final name = data["hostelName"] ?? "Unnamed Hostel";
            final college = data["collegeName"] ?? "Near College";
            final price = data["price"] ?? 0;
            final owner = data["ownerName"] ?? "Unknown Owner";
            final phone = data["ownerPhone"] ?? "N/A";
            final images = data["images"] as List<dynamic>? ?? [];
            final String? imageUrl = images.isNotEmpty ? images.first : null;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imageUrl != null && imageUrl.startsWith("http")
                      ? Image.network(imageUrl, width: 55, height: 55, fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => const Icon(Icons.business, size: 40))
                      : const Icon(Icons.business, size: 40, color: Colors.blue),
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("College: $college"),
                    Text("Owner: $owner ($phone)"),
                    Text("Rent: ₹$price/month", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      tooltip: "Edit Listing",
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditHostelScreen(hostel: doc),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      tooltip: "Delete Hostel Listing",
                      onPressed: () => _deleteHostel(hostelId, name),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUsersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection("users").snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error loading users: ${snapshot.error}"));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                SizedBox(height: 12),
                Text("No users registered yet.", style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          padding: const EdgeInsets.all(10),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final userId = doc.id;
            final name = data["name"] ?? "User";
            final email = data["email"] ?? "No Email";
            final phone = data["phone"] ?? "No Phone";
            final role = (data["role"] ?? "student").toString();

            Color roleColor = Colors.green;
            IconData roleIcon = Icons.school;
            if (role == "manager") {
              roleColor = Colors.orange;
              roleIcon = Icons.business_center;
            } else if (role == "admin") {
              roleColor = Colors.purple;
              roleIcon = Icons.admin_panel_settings;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: roleColor.withOpacity(0.2),
                  child: Icon(roleIcon, color: roleColor),
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Email: $email"),
                    if (phone.isNotEmpty) Text("Phone: $phone"),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Chip(
                      label: Text(
                        role.toUpperCase(),
                        style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                      backgroundColor: roleColor.withOpacity(0.1),
                    ),
                    if (role != "admin")
                      IconButton(
                        icon: const Icon(Icons.person_remove, color: Colors.red),
                        tooltip: "Remove User Account",
                        onPressed: () => _deleteUser(userId, name),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
