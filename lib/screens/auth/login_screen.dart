import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../config/admin_config.dart';
import '../manager/dashboard_screen.dart';
import '../manager/student/student_home_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import 'register_screen.dart';
import 'email_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _secretKeyController = TextEditingController();
  final AuthService _authService = AuthService();
  String _selectedRole = "student";
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _secretKeyController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    // Verify secret key if admin role is selected
    if (_selectedRole == "admin") {
      final secretKeyInput = _secretKeyController.text.trim();
      if (!AdminConfig.validateSecretKey(secretKeyInput)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Invalid Admin Secret Key! Access denied."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await _authService.login(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        String role = _selectedRole; // fallback default

        // Safely fetch or create user role in Firestore if rules allow
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection("users")
              .doc(user.uid)
              .get();

          if (userDoc.exists) {
            final actualRole = userDoc.data()?["role"];
            if (actualRole != null && actualRole != _selectedRole) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Error: You are registered as a $actualRole, not a $_selectedRole.")),
              );
              await _authService.logout();
              return;
            }
            role = actualRole ?? _selectedRole;
          } else {
            // If the user doesn't exist in Firestore collection yet, create it.
            await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
              "uid": user.uid,
              "name": email.split('@').first,
              "email": email,
              "phone": "",
              "role": role,
            });
          }
        } catch (firestoreError) {
          // If Firestore read/write rules restrict access, fallback gracefully to _selectedRole
          debugPrint("Firestore user doc fetch notice: $firestoreError");
        }

        if (!mounted) return;

        // Check if email is verified
        if (!user.emailVerified) {
          // Send a fresh verification email
          await user.sendEmailVerification();

          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please verify your email first. A verification link has been sent to your inbox.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );

          // Redirect to the email verification waiting screen
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const EmailVerificationScreen(),
            ),
            (route) => false,
          );
          return;
        }

        // Email is verified — navigate based on role
        if (role == "admin") {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminDashboardScreen(),
            ),
            (route) => false,
          );
        } else if (role == "manager") {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const DashboardScreen(),
            ),
            (route) => false,
          );
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const StudentHomeScreen(),
            ),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login Failed: ${e.toString()}")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final resetEmailController = TextEditingController(text: _emailController.text.trim());

    final emailToReset = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Reset Password"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Enter your registered email address to receive a password reset link:"),
              const SizedBox(height: 15),
              TextField(
                controller: resetEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
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
                Navigator.pop(context, resetEmailController.text.trim());
              },
              child: const Text("Send Reset Link"),
            ),
          ],
        );
      },
    );

    if (emailToReset != null && emailToReset.isNotEmpty) {
      try {
        await _authService.resetPassword(emailToReset);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Password reset email sent to $emailToReset. Please check your inbox."),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to send reset email: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Login"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.home_work,
                  size: 100,
                  color: Colors.blue,
                ),
                const SizedBox(height: 20),
                const Text(
                  "Welcome to HostelHunt",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),
                AutofillGroup(
                  child: Column(
                    children: [
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: "Email",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        decoration: const InputDecoration(
                          labelText: "Password",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock),
                        ),
                        onEditingComplete: () {
                          TextInput.finishAutofillContext();
                        },
                      ),
                      const SizedBox(height: 5),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _handleForgotPassword,
                          child: const Text("Forgot Password?"),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: "Login as...",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.assignment_ind),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: "student",
                      child: Text("Student"),
                    ),
                    DropdownMenuItem(
                      value: "manager",
                      child: Text("Manager"),
                    ),
                    DropdownMenuItem(
                      value: "admin",
                      child: Text("Admin (System Administrator)"),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedRole = value;
                      });
                    }
                  },
                ),
                if (_selectedRole == "admin") ...[
                  const SizedBox(height: 15),
                  TextField(
                    controller: _secretKeyController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Secret Admin Key",
                      hintText: "Enter secret key",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.key, color: Colors.amber),
                    ),
                  ),
                ],
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "Login",
                            style: TextStyle(fontSize: 18),
                          ),
                  ),
                ),
                const SizedBox(height: 15),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterScreen(),
                      ),
                    );
                  },
                  child: const Text("Don't have an account? Register"),
                ),
                const SizedBox(height: 10),
                Divider(),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.explore),
                  label: const Text("Skip Login & Explore Full App as Guest"),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.blue),
                  ),
                  onPressed: () {
                    if (_selectedRole == "manager") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DashboardScreen(),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StudentHomeScreen(),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}