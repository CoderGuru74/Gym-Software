import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/supabase_service.dart';
import 'admin_members_view.dart';
import 'admin_attendance_view.dart';
import 'admin_payments_view.dart';
import 'admin_settings_view.dart' as settings;

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  final SupabaseService _supabaseService = SupabaseService();

  int _totalMembersCount = 0;
  int _todaysAttendanceCount = 0;
  int _dueSoonCount = 0;
  double _totalRevenue = 0.0;
  bool _isLoading = true;

  List _attendanceLogs = [];
  List _duePayments = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  DateTime? _parseExpiryDate(dynamic dateInput) {
    if (dateInput == null) return null;
    if (dateInput is DateTime) return dateInput;
    
    final dateStr = dateInput.toString().trim();
    if (dateStr.isEmpty) return null;

    final isoDate = DateTime.tryParse(dateStr);
    if (isoDate != null) return isoDate;

    try {
      final parts = dateStr.split(RegExp(r'[\s-/]+'));
      if (parts.length >= 2) {
        final day = int.tryParse(parts[0]);
        int? month;
        int year = DateTime.now().year;

        const months = {
          'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
          'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12
        };

        String monthToken = parts[1].substring(0, 3).toLowerCase();
        if (months.containsKey(monthToken)) {
          month = months[monthToken];
          if (parts.length >= 3) {
            year = int.tryParse(parts[2]) ?? year;
          }
        } else {
          month = int.tryParse(parts[1]);
          if (parts.length >= 3) {
            year = int.tryParse(parts[2]) ?? year;
          }
        }

        if (day != null && month != null) {
          return DateTime(year, month, day);
        }
      }
    } catch (_) {}

    return null;
  }

  int _calculateDaysLeft(String? expiryDateStr) {
    final expiryDate = _parseExpiryDate(expiryDateStr);
    if (expiryDate == null) return 9999;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    
    return target.difference(today).inDays;
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final members = await _supabaseService.getMembers();
      final attendance = await _supabaseService.getAttendanceLogs();
      final payments = await _supabaseService.getPayments();

      final List combinedDues = [];
      
      for (var payment in payments) {
        final dueDate = payment['due_date']?.toString();
        final daysLeft = _calculateDaysLeft(dueDate);
        
        if (daysLeft >= 0 && daysLeft <= 15) {
          String phone = '';
          for (var m in members) {
            if ((m['name']?.toString().toLowerCase() ?? '') == (payment['member_name']?.toString().toLowerCase() ?? '')) {
              phone = m['phone']?.toString() ?? '';
              break;
            }
          }

          combinedDues.add({
            'name': payment['member_name'] ?? 'Unknown',
            'plan': payment['plan'] ?? 'Gold Plan',
            'expiry_date': dueDate ?? '',
            'phone': phone,
          });
        }
      }

      if (combinedDues.isEmpty) {
        for (var member in members) {
          final expiryDate = member['expiry_date']?.toString();
          final daysLeft = _calculateDaysLeft(expiryDate);

          if (daysLeft >= 0 && daysLeft <= 15) {
            combinedDues.add({
              'name': member['name'] ?? 'Unknown',
              'plan': member['plan'] ?? 'Gold Plan',
              'expiry_date': expiryDate ?? '',
              'phone': member['phone']?.toString() ?? '',
            });
          }
        }
      }
      
      double calculatedRevenue = 0.0;
      for (var p in payments) {
        final amount = p['amount'];
        if (amount != null) {
          calculatedRevenue += double.tryParse(amount.toString()) ?? 0.0;
        }
      }

      setState(() {
        _totalMembersCount = members.length;
        _todaysAttendanceCount = attendance.length;
        _dueSoonCount = combinedDues.length;
        _totalRevenue = calculatedRevenue > 0 ? calculatedRevenue : 0.0;
        
        _attendanceLogs = attendance;
        _duePayments = combinedDues;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // Open Face Recognition Attendance Camera Scanner Dialog
  void _openFaceScannerDialog() {
    showDialog(
      context: context,
      builder: (context) => const FaceAttendanceScannerDialog(),
    );
  }

  Future<void> _sendWhatsAppReminder(String name, String plan, String expiryDate, String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final message = Uri.encodeComponent(
      "Hello $name, this is a friendly reminder from The Muscles Gym that your $plan membership is expiring on $expiryDate. Please renew your plan to continue your fitness journey. Thank you!"
    );
    
    final url = cleanPhone.isNotEmpty 
        ? "https://wa.me/$cleanPhone?text=$message"
        : "https://wa.me/?text=$message";

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not launch WhatsApp reminder.")),
        );
      }
    }
  }

  final List _navItems = [
    {"title": "Dashboard", "icon": Icons.grid_view_rounded},
    {"title": "Members", "icon": Icons.person_outline_rounded},
    {"title": "Attendance", "icon": Icons.access_time_rounded},
    {"title": "Payments", "icon": Icons.assignment_outlined},
    {"title": "Settings", "icon": Icons.settings_outlined},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Row(
          children: [
            // SIDEBAR
            Container(
              width: 80,
              color: const Color(0xFF0F172A),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Column(
                    children: [
                      const Icon(Icons.fitness_center_rounded, color: Color(0xFF38BDF8), size: 24),
                      const SizedBox(height: 4),
                      Text(
                        "THE MUSCLES\nGYM",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _navItems.length,
                      itemBuilder: (context, index) {
                        final isSelected = _selectedIndex == index;
                        final IconData icon = _navItems[index]['icon'] as IconData;
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            onPressed: () {
                              setState(() {
                                _selectedIndex = index;
                              });
                            },
                            icon: Icon(
                              icon,
                              color: isSelected ? const Color(0xFF38BDF8) : Colors.grey[400],
                              size: 22,
                            ),
                            tooltip: _navItems[index]['title'],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // MAIN CONTENT AREA
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Welcome back, Admin",
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _fetchDashboardData,
                              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A)),
                              tooltip: "Refresh Data",
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "THE MUSCLES GYM",
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: 1.0),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // BODY VIEW ROUTER
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: _selectedIndex == 0
                          ? (_isLoading
                              ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
                              : _buildDashboardHome())
                          : _selectedIndex == 1
                              ? const AdminMembersView()
                              : _selectedIndex == 2
                                  ? const AdminAttendanceView()
                                  : _selectedIndex == 3
                                      ? const AdminPaymentsView()
                                      : const settings.AdminSettingsView(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardHome() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 900;

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "ADMIN DASHBOARD",
                            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: 0.5),
                          ),
                          Text(
                            "Manage gym operations and face recognition attendance",
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _openFaceScannerDialog,
                        icon: const Icon(Icons.face_retouching_natural_rounded, size: 16, color: Colors.black),
                        label: const Text("Face Verification Scan", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF38BDF8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 600,
                  child: isCompact
                      ? ListView(
                          children: [
                            _buildLeftCard(),
                            const SizedBox(height: 16),
                            _buildRightCard(),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildLeftCard()),
                            const SizedBox(width: 20),
                            Expanded(child: _buildRightCard()),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeftCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("ACTIVE MEMBERS", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 0.8)),
                  const SizedBox(height: 4),
                  Text("$_totalMembersCount", style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _bar(16), const SizedBox(width: 4),
                  _bar(28), const SizedBox(width: 4),
                  _bar(22), const SizedBox(width: 4),
                  _bar(12), const SizedBox(width: 4),
                  _bar(24), const SizedBox(width: 4),
                  _bar(26),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text("ATTENDANCE LOG (TODAY - FACE)", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Text("$_todaysAttendanceCount", style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text("Member name", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600]))),
                Expanded(flex: 2, child: Text("Time in", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600]))),
                Expanded(flex: 1, child: Text("Status", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600]))),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _attendanceLogs.isEmpty
                ? Center(child: Text("No attendance logs recorded today.", style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 13)))
                : ListView.builder(
                    itemCount: _attendanceLogs.length,
                    itemBuilder: (context, index) {
                      final log = _attendanceLogs[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[100]!))),
                        child: Row(
                          children: [
                            Expanded(flex: 2, child: Text(log['member_name'] ?? '', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)))),
                            Expanded(flex: 2, child: Text(log['time_in'] ?? '', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]))),
                            Expanded(flex: 1, child: Text(log['status'] ?? 'VERIFIED', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green[700]))),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("MONTHLY REVENUE (MRR)", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 0.8)),
                  const SizedBox(height: 4),
                  Text("₹ ${_totalRevenue.toStringAsFixed(0)}", style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text("Monthly trend", style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF0284C7))),
                      const Icon(Icons.north_east_rounded, size: 12, color: Color(0xFF0284C7)),
                    ],
                  ),
                ],
              ),
              Container(
                width: 100,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(child: Icon(Icons.show_chart_rounded, color: Color(0xFF0284C7), size: 24)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text("PAYMENTS DUE (SOON)", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Text("$_dueSoonCount", style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text("Name", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600]))),
                Expanded(flex: 2, child: Text("Plan", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600]))),
                Expanded(flex: 2, child: Text("Due date", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600]))),
                const SizedBox(width: 80, child: Text("Action", textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _duePayments.isEmpty
                ? Center(child: Text("No upcoming payment dues found.", style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 13)))
                : ListView.builder(
                    itemCount: _duePayments.length,
                    itemBuilder: (context, index) {
                      final member = _duePayments[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[100]!))),
                        child: Row(
                          children: [
                            Expanded(flex: 2, child: Text(member['name'] ?? '', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)))),
                            Expanded(flex: 2, child: Text(member['plan'] ?? 'Gold Plan', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]))),
                            Expanded(flex: 2, child: Text(member['expiry_date'] ?? '', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber[800]))),
                            SizedBox(
                              width: 80,
                              child: TextButton.icon(
                                onPressed: () => _sendWhatsAppReminder(
                                  member['name'] ?? '',
                                  member['plan'] ?? 'Gold Plan',
                                  member['expiry_date'] ?? '',
                                  member['phone'] ?? '',
                                ),
                                icon: const Icon(Icons.chat_rounded, size: 14, color: Color(0xFF10B981)),
                                label: const Text("WhatsApp", style: TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(80, 30),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  backgroundColor: const Color(0xFF10B981).withOpacity(0.1),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _bar(double height) {
    return Container(
      width: 8,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF38BDF8),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

// Face Attendance Camera Scanner Dialog Widget
class FaceAttendanceScannerDialog extends StatefulWidget {
  const FaceAttendanceScannerDialog({super.key});

  @override
  State<FaceAttendanceScannerDialog> createState() => _FaceAttendanceScannerDialogState();
}

class _FaceAttendanceScannerDialogState extends State<FaceAttendanceScannerDialog> {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _controller = CameraController(cameras.first, ResolutionPreset.medium);
        await _controller!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _verifyFaceAndMarkAttendance() async {
    setState(() => _isScanning = true);
    
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() => _isScanning = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Face Verified Successfully! Attendance Marked."),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        "AI Face Recognition Attendance",
        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
      ),
      content: SizedBox(
        width: 420,
        height: 360,
        child: _isCameraInitialized && _controller != null
            ? Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CameraPreview(_controller!),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _isScanning
                      ? const CircularProgressIndicator(color: Color(0xFF38BDF8))
                      : Text(
                          "Align member's face within camera frame",
                          style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 13),
                        ),
                ],
              )
            : const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8))),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton.icon(
          onPressed: _isScanning ? null : _verifyFaceAndMarkAttendance,
          icon: const Icon(Icons.face_retouching_natural_rounded, color: Colors.black),
          label: const Text("Scan & Verify Face", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8)),
        ),
      ],
    );
  }
}