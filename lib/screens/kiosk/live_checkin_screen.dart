import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class LiveCheckinScreen extends StatefulWidget {
  const LiveCheckinScreen({super.key});

  @override
  State<LiveCheckinScreen> createState() => _LiveCheckinScreenState();
}

class _LiveCheckinScreenState extends State<LiveCheckinScreen> {
  late String _timeString;
  late String _dateString;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timeString = DateFormat('hh:mm').format(DateTime.now());
    _dateString = DateFormat('EEEE • dd MMMM yyyy').format(DateTime.now()).toUpperCase();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _updateTime());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateTime() {
    setState(() {
      _timeString = DateFormat('hh:mm').format(DateTime.now());
      _dateString = DateFormat('EEEE • dd MMMM yyyy').format(DateTime.now()).toUpperCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    const darkPanelColor = Color(0xFF1E293B);
    const lightBgColor = Color(0xFFF0F4F8);

    return Scaffold(
      backgroundColor: lightBgColor,
      body: Row(
        children: [
          // 1. LEFT DARK BRANDING & CLOCK PANEL
          Container(
            width: MediaQuery.of(context).size.width * 0.35,
            color: darkPanelColor,
            padding: const EdgeInsets.all(48.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "WELCOME TO",
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.0,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "APEX FITNESS",
                  style: GoogleFonts.inter(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 80),
                Text(
                  _timeString,
                  style: GoogleFonts.inter(
                    fontSize: 68,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _dateString,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),

          // 2. RIGHT RECENT CHECK-INS FEED
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "RECENT CHECK-INS",
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: darkPanelColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView(
                      children: [
                        _buildCheckinCard("Rahul Sharma", "Member • Gold Plan • 07:15 AM", "R", Colors.blueGrey),
                        _buildCheckinCard("Anita Singh", "Member • Gold Plan • 07:30 AM", "A", Colors.blue),
                        _buildCheckinCard("Vikram Patel", "Member • Gold Plan • 07:30 AM", "V", Colors.blueGrey),
                        _buildCheckinCard("Viram Patel", "Member • Gold Plan • 07:35 AM", "V", Colors.lightBlue),
                        _buildCheckinCard("Priya Verma", "Member • Gold Plan • 07:40 AM", "P", Colors.blueGrey),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget for check-in feed rows
  Widget _buildCheckinCard(String name, String subtitle, String initial, Color avatarColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar Circle
          CircleAvatar(
            radius: 22,
            backgroundColor: avatarColor,
            child: Text(
              initial,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Name & Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          // Success Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "CHECK-IN SUCCESS",
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}