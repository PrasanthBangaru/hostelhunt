import 'package:flutter/material.dart';

class EmailService {
  static void sendLoginAlert(BuildContext context, String email) {
    // In a real production app, this would trigger a Cloud Function
    // that uses SendGrid/Nodemailer to send the actual email.
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Security Alert: Mock Email sent to $email"),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'View Email',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EmailSimulatorScreen()),
            );
          },
        ),
      ),
    );
  }
}

class EmailSimulatorScreen extends StatelessWidget {
  const EmailSimulatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Simulated Inbox"),
        backgroundColor: Colors.grey.shade200,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.security, size: 50, color: Colors.blue),
              const SizedBox(height: 20),
              const Text(
                "New Login Alert",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              const Text(
                "We noticed a new login to your HostelHunt account. Was this you?",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      // Handle 'No'
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text("Account Secured"),
                          content: const Text("We will abort this login attempt and secure your account."),
                          actions: [
                            TextButton(
                              onPressed: () {
                                // Close dialog, then pop screen with false
                                Navigator.pop(context);
                                Navigator.pop(context, false);
                              },
                              child: const Text("OK"),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text("No, I'm not"),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      // Handle 'Yes'
                      Navigator.pop(context, true);
                    },
                    child: const Text("Yes, I'm"),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
