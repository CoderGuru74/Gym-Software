import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'admin_dashboard_screen.dart';

class MemberVerificationScreen extends StatefulWidget {
  const MemberVerificationScreen({super.key});

  @override
  State<MemberVerificationScreen> createState() => _MemberVerificationScreenState();
}

class _MemberVerificationScreenState extends State<MemberVerificationScreen> {
  late Timer _timer;
  late DateTime _currentTime;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _simulateScan() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Scan Successful", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text("Welcome back, Rahul Sharma!\nPlan: Gold Plan (Active)", style: GoogleFonts.inter(color: Colors.grey[300], fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Done", style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showStaffPinDialog() {
    final TextEditingController pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Enter Staff PIN", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: pinController,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Enter 4-digit PIN",
            hintStyle: TextStyle(color: Colors.grey[600]),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFF59E0B))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Login", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String formattedTime = DateFormat('hh:mm:ss a').format(_currentTime);
    String formattedDate = DateFormat('EEEE, dd MMMM yyyy').format(_currentTime);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // CINEMATIC BACKGROUND IMAGE WITH DARK OVERLAY
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: const AssetImage('assets/images/gym_bg.jpg'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.65),
                    BlendMode.darken,
                  ),
                ),
              ),
            ),
          ),

          // MAIN CONTENT LAYOUT
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
            child: Column(
              children: [
                // TOP HEADER: BRAND + REAL-TIME CLOCK
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            'assets/images/muscle.jpeg',
                            width: 46,
                            height: 46,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "THE MUSCLES GYM",
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFFF59E0B),
                                letterSpacing: 1.5,
                              ),
                            ),
                            Text(
                              "STRONGER THAN YESTERDAY",
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[400],
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Right Real-Time Date & Time Clock
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formattedTime,
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            Text(
                              formattedDate,
                              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),

                // PROFESSIONAL CENTER VERIFICATION CARD
                Center(
                  child: Container(
                    width: 480,
                    padding: const EdgeInsets.all(36),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161619),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF2A2A30), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Member Check-In",
                          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Place your finger on the biometric scanner",
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[400]),
                        ),
                        const SizedBox(height: 32),

                        // CLEAN FINGERPRINT ICON BUTTON
                        GestureDetector(
                          onTap: _simulateScan,
                          child: Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF1E1E22),
                              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4), width: 1.5),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.fingerprint_rounded,
                                size: 52,
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Text(
                          "Waiting for fingerprint...",
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[300]),
                        ),
                        const SizedBox(height: 32),

                        // STAFF PIN BUTTON
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _showStaffPinDialog,
                            icon: const Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFFF59E0B)),
                            label: Text(
                              "Staff Dashboard Login",
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF3A3A42)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              backgroundColor: const Color(0xFF1A1A1E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),

                // BOTTOM STATUS BADGES
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildBadge(Icons.security_rounded, "SECURE KIOSK"),
                    const SizedBox(width: 28),
                    _buildBadge(Icons.bolt_rounded, "INSTANT SYNC"),
                    const SizedBox(width: 28),
                    _buildBadge(Icons.verified_user_rounded, "BIOMETRIC ACTIVE"),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFFF59E0B)),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[400], letterSpacing: 0.8),
        ),
      ],
    );
  }
}