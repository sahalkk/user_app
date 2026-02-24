import 'package:beeyo_customer/blocs/auth_bloc/auth_bloc.dart';
import 'package:beeyo_customer/blocs/auth_bloc/auth_event.dart';
import 'package:beeyo_customer/blocs/auth_bloc/auth_state.dart';
import 'package:beeyo_customer/screens/profile/views/wishlist_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Make sure these paths match your folder structure
import '../../auth/views/login_screen.dart';

class ProfileScreen extends StatelessWidget {
  final VoidCallback? onNavigateToOrders;

  const ProfileScreen({super.key, this.onNavigateToOrders});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthAuthenticated) {
            // USER IS LOGGED IN
            return _buildLoggedInProfile(context, state);
          } else {
            // USER IS A GUEST
            return _buildGuestProfile(context);
          }
        },
      ),
    );
  }

  // ==========================================
  // 1. GUEST PROFILE VIEW
  // ==========================================
  Widget _buildGuestProfile(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                  child:
                      Icon(Icons.person, size: 50, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Your account",
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87),
                ),
                const SizedBox(height: 6),
                Text(
                  "Log in to view your complete profile",
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const LoginScreen()),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.green.shade600, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          "Continue",
                          style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Other Information",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading:
                            const Icon(Icons.ios_share, color: Colors.black54),
                        title: const Text("Share the app",
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        trailing:
                            const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {},
                      ),
                      Divider(
                          height: 1,
                          thickness: 1,
                          indent: 16,
                          endIndent: 16,
                          color: Colors.grey.shade100),
                      ListTile(
                        leading: const Icon(Icons.info_outline,
                            color: Colors.black54),
                        title: const Text("About us",
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        trailing:
                            const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildFooter(),
      ],
    );
  }

  // ==========================================
  // 2. LOGGED-IN PROFILE VIEW (UPDATED)
  // ==========================================
  Widget _buildLoggedInProfile(BuildContext context, AuthAuthenticated state) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 10),
                // Avatar Header
                Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      "U",
                      style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "My Account",
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87),
                ),
                const SizedBox(height: 6),
                Text(
                  "+91 XXXXX XXXXX",
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 32),

                // --- FIRST SECTION (Main Items) ---
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.book_outlined,
                            color: Colors.black54),
                        title: const Text("Address Book",
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        trailing:
                            const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {},
                      ),
                      Divider(
                          height: 1,
                          thickness: 1,
                          indent: 16,
                          endIndent: 16,
                          color: Colors.grey.shade100),
                      ListTile(
                        leading: const Icon(Icons.favorite_border, color: Colors.black54),
                        title: const Text("Your Wishlist", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {
                          // 🔥 Navigate to the new Wishlist screen!
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const WishlistScreen()),
                          );
                        },
                      ),
                      Divider(
                          height: 1,
                          thickness: 1,
                          indent: 16,
                          endIndent: 16,
                          color: Colors.grey.shade100),
                      ListTile(
                        leading: const Icon(Icons.payment_outlined,
                            color: Colors.black54),
                        title: const Text("Payment Settings",
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        trailing:
                            const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // --- OTHER INFORMATION SECTION ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Other Information",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading:
                            const Icon(Icons.ios_share, color: Colors.black54),
                        title: const Text("Share the app",
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        trailing:
                            const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {},
                      ),
                      Divider(
                          height: 1,
                          thickness: 1,
                          indent: 16,
                          endIndent: 16,
                          color: Colors.grey.shade100),
                      ListTile(
                        leading: const Icon(Icons.info_outline,
                            color: Colors.black54),
                        title: const Text("About us",
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        trailing:
                            const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {},
                      ),
                      Divider(
                          height: 1,
                          thickness: 1,
                          indent: 16,
                          endIndent: 16,
                          color: Colors.grey.shade100),
                      ListTile(
                        leading: const Icon(Icons.lock_outline,
                            color: Colors.black54),
                        title: const Text("Account Privacy",
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        trailing:
                            const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {},
                      ),
                      Divider(
                          height: 1,
                          thickness: 1,
                          indent: 16,
                          endIndent: 16,
                          color: Colors.grey.shade100),
                      ListTile(
                        leading:
                            const Icon(Icons.logout, color: Colors.black54),
                        title: const Text("Log out",
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        trailing:
                            const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {
                          // Dispatches the logout event to AuthBloc
                          context.read<AuthBloc>().add(LogoutRequested());
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
        _buildFooter(),
      ],
    );
  }

  // ==========================================
  // 3. REUSABLE FOOTER (Beeyo Logo)
  // ==========================================
  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32.0, top: 16.0),
      child: Column(
        children: [
          Text(
            "Beeyo",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.grey.shade400,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "v1.0.0",
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade400,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
