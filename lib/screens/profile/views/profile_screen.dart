import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

// Auth & Cart Imports
import '../../../../blocs/auth_bloc/auth_bloc.dart';
import '../../../../blocs/auth_bloc/auth_event.dart';
import '../../../../blocs/cart_bloc/cart_bloc.dart'; // To clear the cart

// Navigation Import
import '../../main_wrapper.dart'; // To navigate home
import '../../auth/views/login_screen.dart'; // To navigate to login after logout

class ProfileScreen extends StatelessWidget {
  final VoidCallback onNavigateToOrders;

  const ProfileScreen({super.key, required this.onNavigateToOrders});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        elevation: 0,
        centerTitle: true,
        title: const Text("Profile",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserCard(),

            const SizedBox(height: 32),

            // 1. Account Section
            const Text("Account",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildMenuContainer([
              _buildMenuItem(
                  Icons.person_outline, "Account Information", () {}),
              _buildMenuItem(
                  Icons.receipt_long_outlined, "My Orders", onNavigateToOrders),
              _buildMenuItem(
                  Icons.location_on_outlined, "Address Management", () {}),
              _buildMenuItem(Icons.settings_outlined, "Setting", () {}),
              _buildMenuItem(Icons.lock_outline, "Password Manager", () {}),
            ]),

            const SizedBox(height: 32),

            // 2. About Section
            const Text("About",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildMenuContainer([
              _buildMenuItem(Icons.share_outlined, "Share the App", () {
                SharePlus.instance.share(
                  ShareParams(
                    text:
                        'Check out Beeyo, Essentials at your Doorstep! Download it here: https://play.google.com/store/apps/details?id=com.beeyo.customer',
                    subject: 'Download Beeyo App!',
                  ),
                );
              }),
              _buildMenuItem(Icons.info_outline, "About Us", () {}),
              _buildMenuItem(Icons.shield_outlined, "Privacy Policy", () {}),
            ]),

            const SizedBox(height: 32),

            // 3. Support Section
            const Text("Support",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildMenuContainer([
              _buildMenuItem(Icons.help_outline, "Help Center", () {}),

              // --- UPDATED LOGOUT BUTTON ---
              _buildMenuItem(Icons.logout, "Logout", () {
                // 1. Clear the Cart
                context.read<CartBloc>().add(ClearCart());

                // 2. Clear Auth Session
                context.read<AuthBloc>().add(LogoutRequested());

                // 3. Navigate to Login Screen but keep the app route below so
                // closing the login screen returns user to Home as a guest.
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Logged out successfully")),
                );
              }, isDestructive: true),
              // ------------------------------
            ]),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.grey.shade200,
            child: const Icon(Icons.person, size: 30, color: Colors.grey),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Jon Alishon", // Still Hardcoded
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text("alishon35@gmail.com",
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.edit, size: 16, color: Colors.black),
            label: const Text("Edit", style: TextStyle(color: Colors.black)),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: Colors.grey.shade300),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuContainer(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap,
      {bool isDestructive = false}) {
    return ListTile(
      leading:
          Icon(icon, color: isDestructive ? Colors.red : Colors.grey.shade700),
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isDestructive ? Colors.red : Colors.black)),
      trailing:
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    );
  }
}
