import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/supabase_service.dart';
import 'admin_members_view.dart';
import 'admin_attendance_view.dart';
import 'admin_payments_view.dart';
import 'admin_settings_view.dart';

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

  // Universal date parser supporting both ISO (2026-11-06) and text formats (06 Nov 2026)
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
          combinedDues.add({
            'name': payment['member_name'] ?? 'Unknown',
            'plan': payment['plan'] ?? 'Gold Plan',
            'expiry_date': dueDate ?? '',
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
      body: Row(
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
                      "APEX\nFITNESS",
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
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
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
                          const SizedBox(width: 12),
                          Text(
                            "APEX FITNESS",
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: 1.0),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // BODY VIEW ROUTER
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
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
                                    : const AdminSettingsView(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardHome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "02 ADMIN DASHBOARD",
                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: 0.5),
              ),
              Text(
                "Manage your gym operations at a glance",
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT CARD: Members & Attendance
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
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
                              const SizedBox(height: 6),
                              Text("$_totalMembersCount", style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                            ],
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _bar(18), const SizedBox(width: 4),
                              _bar(32), const SizedBox(width: 4),
                              _bar(24), const SizedBox(width: 4),
                              _bar(14), const SizedBox(width: 4),
                              _bar(28), const SizedBox(width: 4),
                              _bar(30),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text("ATTENDANCE LOG (TODAY)", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 0.8)),
                      const SizedBox(height: 6),
                      Text("$_todaysAttendanceCount", style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                      const SizedBox(height: 24),
                      Text("ATTENDANCE LOG (TODAY)", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 0.8)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                        child: Row(
                          children: [
                            Expanded(flex: 2, child: Text("Member name", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600]))),
                            Expanded(flex: 2, child: Text("Time in", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600]))),
                            Expanded(flex: 1, child: Text("Status", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600]))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _attendanceLogs.isEmpty
                            ? Center(child: Text("No attendance logs recorded today.", style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 13)))
                            : ListView.builder(
                                itemCount: _attendanceLogs.length,
                                itemBuilder: (context, index) {
                                  final log = _attendanceLogs[index];
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[100]!))),
                                    child: Row(
                                      children: [
                                        Expanded(flex: 2, child: Text(log['member_name'] ?? '', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)))),
                                        Expanded(flex: 2, child: Text(log['time_in'] ?? '', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]))),
                                        Expanded(flex: 1, child: Text(log['status'] ?? 'CHECK-IN', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // RIGHT CARD: Revenue & Payments Due
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
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
                              const SizedBox(height: 6),
                              Text("₹ ${_totalRevenue.toStringAsFixed(0)}", style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text("Monthly trend", style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF0284C7))),
                                  const Icon(Icons.north_east_rounded, size: 12, color: Color(0xFF0284C7)),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            width: 140,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE).withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(child: Icon(Icons.show_chart_rounded, color: Color(0xFF0284C7), size: 28)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text("PAYMENTS DUE (SOON)", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 0.8)),
                      const SizedBox(height: 6),
                      Text("$_dueSoonCount", style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                      const SizedBox(height: 24),
                      Text("PAYMENTS DUE (SOON)", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 0.8)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                        child: Row(
                          children: [
                            Expanded(flex: 2, child: Text("Name", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600]))),
                            Expanded(flex: 2, child: Text("Plan", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600]))),
                            Expanded(flex: 2, child: Text("Due date", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600]))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _duePayments.isEmpty
                            ? Center(child: Text("No upcoming payment dues found.", style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 13)))
                            : ListView.builder(
                                itemCount: _duePayments.length,
                                itemBuilder: (context, index) {
                                  final member = _duePayments[index];
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[100]!))),
                                    child: Row(
                                      children: [
                                        Expanded(flex: 2, child: Text(member['name'] ?? '', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)))),
                                        Expanded(flex: 2, child: Text(member['plan'] ?? 'Gold Plan', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]))),
                                        Expanded(flex: 2, child: Text(member['expiry_date'] ?? '', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.amber[800]))),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bar(double height) {
    return Container(
      width: 10,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF38BDF8),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}