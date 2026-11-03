import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../admin/admin_dashboard_screen.dart';

class MuscleGymIdleScreen extends StatefulWidget {
  const MuscleGymIdleScreen({super.key});

  @override
  State<MuscleGymIdleScreen> createState() => _MuscleGymIdleScreenState();
}

class _MuscleGymIdleScreenState extends State<MuscleGymIdleScreen> {
  late String _timeString;
  late String _dateString;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timeString = _formatTime(DateTime.now());
    _dateString = _formatDate(DateTime.now());
    
    // Update clock every second
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _updateTime());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateTime() {
    setState(() {
      _timeString = _formatTime(DateTime.now());
      _dateString = _formatDate(DateTime.now());
    });
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('hh:mm:ss a').format(dateTime);
  }

  String _formatDate(DateTime dateTime) {
    return DateFormat('EEEE, dd MMMM yyyy').format(dateTime);
  }

  // Function to show the PIN entry dialog
  void _showStaffPinDialog(BuildContext context) {
    TextEditingController pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Staff Authentication",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: pinController,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          decoration: const InputDecoration(
            labelText: "Enter 4-Digit Staff PIN (Try 1234)",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              // Default test PIN is set to 1234
              if (pinController.text == "1234") {
                Navigator.pop(context); // Close dialog
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminDashboardScreen(),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Incorrect PIN. Please try 1234")),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
            ),
            child: const Text("Login"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Light grayish-blue background matching your design
    const backgroundColor = Color(0xFFF0F4F8);
    const cardColor = Colors.white;
    const primaryColor = Color(0xFF1E293B);
    const accentColor = Color(0xFF0284C7);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
          child: Stack(
            children: [
              // TOP RIGHT: Real-time Clock & Date
              Positioned(
                top: 0,
                right: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _timeString,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _dateString,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // CENTER: Main Brand Header & Content Card
              Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Brand Header
                      Text(
                        "MUSCLE GYM",
                        style: GoogleFonts.inter(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "SECURE GYM ACCESS",
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Central Card Container
                      Container(
                        width: 460,
                        padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 32.0),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(20.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Welcome to Muscle Gym",
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Member verification",
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Fingerprint Icon / Animation Placeholder
                            Container(
                              height: 110,
                              width: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: backgroundColor,
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.fingerprint,
                                  size: 64,
                                  color: accentColor.withOpacity(0.8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Action Text
                            Text(
                              "Place Finger to Scan",
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Or use your staff credentials",
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Staff PIN Button
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: ElevatedButton(
                                onPressed: () {
                                  _showStaffPinDialog(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  "Use Staff PIN",
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // BOTTOM FOOTER TAGLINE
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    "SECURE • FAST • EFFORTLESS",
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                      color: Colors.grey[500],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}