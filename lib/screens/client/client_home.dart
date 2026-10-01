import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ClientHome extends StatelessWidget {
  const ClientHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SkillBridge'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: const Center(
        child: Text('Client Home', style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
