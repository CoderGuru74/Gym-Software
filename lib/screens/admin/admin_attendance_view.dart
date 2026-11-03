import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/supabase_service.dart';

class AdminAttendanceView extends StatefulWidget {
  const AdminAttendanceView({super.key});

  @override
  State<AdminAttendanceView> createState() => _AdminAttendanceViewState();
}

class _AdminAttendanceViewState extends State<AdminAttendanceView> {
  final _supabaseService = SupabaseService();
  List _attendanceList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAttendance();
  }

  Future<void> _fetchAttendance() async {
    try {
      final data = await _supabaseService.getAttendanceLogs();
      setState(() {
        _attendanceList = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1E293B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "LIVE ATTENDANCE LOG",
                  style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: primaryColor),
                ),
                Text(
                  "Real-time biometric check-in stream from the kiosk",
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
            IconButton(
              onPressed: _fetchAttendance,
              icon: const Icon(Icons.refresh_rounded, color: primaryColor),
              tooltip: "Refresh Log",
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5)),
              ],
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B)))
                : _attendanceList.isEmpty
                    ? Center(
                        child: Text(
                          "No attendance logs recorded yet today.",
                          style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 14),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Expanded(flex: 2, child: Text("Member Name", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
                                Expanded(flex: 2, child: Text("Check-In Time", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
                                Expanded(flex: 2, child: Text("Status", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _attendanceList.length,
                              itemBuilder: (context, index) {
                                final log = _attendanceList[index];
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  margin: const EdgeInsets.only(bottom: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[100]!),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(flex: 2, child: Text(log['member_name'] ?? '', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: primaryColor))),
                                      Expanded(flex: 2, child: Text(log['time_in'] ?? '', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]))),
                                      Expanded(
                                        flex: 2,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.green[50],
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              log['status'] ?? 'CHECK-IN',
                                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green[700]),
                                            ),
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
          ),
        ),
      ],
    );
  }
}