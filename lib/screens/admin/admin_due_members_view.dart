import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/supabase_service.dart';

class AdminDueMembersView extends StatefulWidget {
  const AdminDueMembersView({super.key});

  @override
  State<AdminDueMembersView> createState() => _AdminDueMembersViewState();
}

class _AdminDueMembersViewState extends State<AdminDueMembersView> {
  final _supabaseService = SupabaseService();
  List _dueMembers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDueMembers();
  }

  Future<void> _fetchDueMembers() async {
    try {
      final members = await _supabaseService.getMembers();
      setState(() {
        _dueMembers = members.where((m) => (m['days_left'] ?? 30) <= 5).toList();
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
                  "MEMBERSHIPS DUE SOON",
                  style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: primaryColor),
                ),
                Text(
                  "Members requiring renewal or payment follow-up",
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
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
                : _dueMembers.isEmpty
                    ? Center(
                        child: Text(
                          "No memberships due soon. All members are active!",
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
                                Expanded(flex: 2, child: Text("Phone", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
                                Expanded(flex: 2, child: Text("Plan", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
                                Expanded(flex: 1, child: Text("Days Left", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _dueMembers.length,
                              itemBuilder: (context, index) {
                                final member = _dueMembers[index];
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
                                      Expanded(flex: 2, child: Text(member['name'] ?? '', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: primaryColor))),
                                      Expanded(flex: 2, child: Text(member['phone'] ?? '', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]))),
                                      Expanded(flex: 2, child: Text(member['plan'] ?? '', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[800]))),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          "${member['days_left'] ?? 0} days",
                                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red[700]),
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