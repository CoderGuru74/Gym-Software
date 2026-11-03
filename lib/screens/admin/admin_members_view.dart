import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/supabase_service.dart';

class AdminMembersView extends StatefulWidget {
  const AdminMembersView({super.key});

  @override
  State<AdminMembersView> createState() => _AdminMembersViewState();
}

class _AdminMembersViewState extends State<AdminMembersView> {
  final _supabaseService = SupabaseService();
  List _members = [];
  bool _isLoading = true;

  Map<String, dynamic>? _selectedMember;
  int _profileTabIdx = 0;
  List _memberAttendance = [];
  bool _isLoadingProfileAttendance = false;

  final List _paymentLedger = [
    {"id": "TXN-9021", "plan": "Gold Plan", "amount": "₹ 2,500 (Paid)"},
  ];

  String _selectedMonthFilter = "All Months";

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabaseService.getMembers();
      setState(() {
        _members = data;
        _isLoading = false;
        if (_selectedMember != null) {
          _selectedMember = _members.firstWhere(
            (m) => m['id'] == _selectedMember!['id'],
            orElse: () => _selectedMember!,
          );
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMemberAttendance(String memberName) async {
    setState(() => _isLoadingProfileAttendance = true);
    try {
      final allLogs = await _supabaseService.getAttendanceLogs();
      final userLogs = allLogs.where((log) => log['member_name'] == memberName).toList();
      setState(() {
        _memberAttendance = userLogs;
        _isLoadingProfileAttendance = false;
      });
    } catch (e) {
      setState(() => _isLoadingProfileAttendance = false);
    }
  }

  DateTime? _parseExpiryDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    try {
      final cleanStr = dateStr.trim();
      final parts = cleanStr.split(RegExp(r'\s+'));
      if (parts.length < 2) return null;

      final day = int.parse(parts[0]);
      final monthStr = parts[1].substring(0, 3).toLowerCase();
      
      int year = DateTime.now().year;
      if (parts.length >= 3) {
        year = int.parse(parts[2]);
      }

      const months = {
        'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
        'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12
      };
      final month = months[monthStr] ?? 1;

      return DateTime(year, month, day);
    } catch (e) {
      return null;
    }
  }

  // Returns exact remaining days. Returns a safe high number (9999) if invalid so it never triggers due-soon mistakenly.
  int _calculateDaysLeft(String? expiryDateStr) {
    final expiryDate = _parseExpiryDate(expiryDateStr);
    if (expiryDate == null) return 9999; 
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    
    return target.difference(today).inDays;
  }

  String _monthName(int month) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month];
  }

  void _showAddMemberDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    
    final int nextRollNum = 1000 + _members.length + 1;
    final TextEditingController rollNoController = TextEditingController(text: "ADM-$nextRollNum");

    String selectedPlan = 'Gold Plan';
    String selectedDuration = '30 Days';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            "Register New Member",
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameController, style: const TextStyle(color: Colors.white), decoration: _inputDecoration("Full Name")),
                  const SizedBox(height: 12),
                  TextField(controller: rollNoController, style: const TextStyle(color: Colors.white), decoration: _inputDecoration("Admission ID / Roll No")),
                  const SizedBox(height: 12),
                  TextField(controller: phoneController, style: const TextStyle(color: Colors.white), decoration: _inputDecoration("Phone Number")),
                  const SizedBox(height: 12),
                  TextField(controller: emailController, style: const TextStyle(color: Colors.white), decoration: _inputDecoration("Email (Optional)")),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedPlan,
                    dropdownColor: const Color(0xFF2A2A32),
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration("Membership Plan"),
                    items: ['Silver Plan', 'Gold Plan', 'Platinum Plan', 'Annual Plan']
                        .map((plan) => DropdownMenuItem(value: plan, child: Text(plan)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedPlan = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedDuration,
                    dropdownColor: const Color(0xFF2A2A32),
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration("Membership Duration"),
                    items: ['10 Days', '30 Days', '90 Days', '180 Days', '365 Days']
                        .map((dur) => DropdownMenuItem(value: dur, child: Text(dur)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedDuration = val);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty || phoneController.text.trim().isEmpty) return;
                try {
                  int daysCount = 30;
                  if (selectedDuration.contains('10')) daysCount = 10;
                  if (selectedDuration.contains('90')) daysCount = 90;
                  if (selectedDuration.contains('180')) daysCount = 180;
                  if (selectedDuration.contains('365')) daysCount = 365;

                  final expiryDate = DateTime.now().add(Duration(days: daysCount));
                  final expiryString = "${expiryDate.day} ${_monthName(expiryDate.month)} ${expiryDate.year}";

                  final Map<String, dynamic> insertData = {
                    'name': nameController.text.trim(),
                    'phone': phoneController.text.trim(),
                  };

                  try {
                    insertData['roll_no'] = rollNoController.text.trim();
                    insertData['plan'] = selectedPlan;
                    insertData['status'] = 'ACTIVE';
                    insertData['days_left'] = daysCount;
                    insertData['expiry_date'] = expiryString;
                    if (emailController.text.trim().isNotEmpty) {
                      insertData['email'] = emailController.text.trim();
                    }
                  } catch (_) {}

                  await _supabaseService.client.from('members').insert(insertData);

                  Navigator.pop(context);
                  _fetchMembers();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Member registered successfully!")));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8)),
              child: const Text("Save Member", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditMemberDialog(Map<String, dynamic> member) {
    final TextEditingController nameController = TextEditingController(text: member['name'] ?? '');
    final TextEditingController phoneController = TextEditingController(text: member['phone'] ?? '');
    final TextEditingController expiryController = TextEditingController(text: member['expiry_date'] ?? '12 Nov 2026');
    String selectedPlan = member['plan'] ?? 'Gold Plan';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("Edit Member Profile", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameController, style: const TextStyle(color: Colors.white), decoration: _inputDecoration("Full Name")),
                  const SizedBox(height: 12),
                  TextField(controller: phoneController, style: const TextStyle(color: Colors.white), decoration: _inputDecoration("Phone Number")),
                  const SizedBox(height: 12),
                  TextField(controller: expiryController, style: const TextStyle(color: Colors.white), decoration: _inputDecoration("Expiry Date (e.g. 12 Nov 2026)")),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedPlan,
                    dropdownColor: const Color(0xFF2A2A32),
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration("Membership Plan"),
                    items: ['Silver Plan', 'Gold Plan', 'Platinum Plan', 'Annual Plan']
                        .map((plan) => DropdownMenuItem(value: plan, child: Text(plan)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedPlan = val);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty || phoneController.text.trim().isEmpty) return;
                try {
                  final newExpiryStr = expiryController.text.trim();
                  final newDaysLeft = _calculateDaysLeft(newExpiryStr);

                  final Map<String, dynamic> updateData = {
                    'name': nameController.text.trim(),
                    'phone': phoneController.text.trim(),
                    'plan': selectedPlan,
                    'expiry_date': newExpiryStr,
                    'days_left': newDaysLeft,
                  };

                  await _supabaseService.client.from('members').update(updateData).eq('id', member['id']);

                  Navigator.pop(context);
                  await _fetchMembers();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Member profile updated successfully!")));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error updating: $e")));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8)),
              child: const Text("Update Member", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteMemberDialog(Map<String, dynamic> member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Delete Member", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text(
          "Are you sure you want to permanently delete '${member['name']}' and all associated records? This action cannot be undone.",
          style: GoogleFonts.inter(color: Colors.grey[300], fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              try {
                await _supabaseService.client.from('members').delete().eq('id', member['id']);
                Navigator.pop(context);
                setState(() => _selectedMember = null);
                await _fetchMembers();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Member deleted successfully!")));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error deleting member: $e")));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
            child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[400]),
      filled: true,
      fillColor: const Color(0xFF2A2A32),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF38BDF8))),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedMember != null) {
      return _buildMemberProfileView();
    }
    return _buildMembersListView();
  }

  Widget _buildMembersListView() {
    const primaryColor = Color(0xFF0F172A);

    final filteredMembers = _members.where((member) {
      if (_selectedMonthFilter == "All Months") return true;
      final expiryStr = (member['expiry_date'] ?? '').toString().toLowerCase();
      return expiryStr.contains(_selectedMonthFilter.toLowerCase());
    }).toList();

    final List monthFilterOptions = [
      "All Months",
      "Jan", "Feb", "Mar", "Apr", "May", "Jun", 
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("MEMBER MANAGEMENT", style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: primaryColor)),
                Text("Manage gym members and database records", style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: DropdownButton<String>(
                    value: monthFilterOptions.contains(_selectedMonthFilter) ? _selectedMonthFilter : "All Months",
                    underline: const SizedBox(),
                    dropdownColor: Colors.white,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: primaryColor),
                    items: monthFilterOptions.map((month) {
                      return DropdownMenuItem<String>(
                        value: month,
                        child: Text(month == "All Months" ? "All Months" : month),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedMonthFilter = val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(onPressed: _fetchMembers, icon: const Icon(Icons.refresh_rounded, color: primaryColor), tooltip: "Refresh List"),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _showAddMemberDialog,
                  icon: const Icon(Icons.person_add_rounded, size: 16),
                  label: const Text("Add New Member"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
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
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
                : filteredMembers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.group_off_rounded, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text("No members found expiring in '$_selectedMonthFilter'.", style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 15, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                            child: Row(
                              children: [
                                Expanded(flex: 2, child: Text("Member Name", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
                                Expanded(flex: 1, child: Text("Roll No", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
                                Expanded(flex: 2, child: Text("Phone", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
                                Expanded(flex: 2, child: Text("Plan", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
                                Expanded(flex: 1, child: Text("Status", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
                                Expanded(flex: 2, child: Text("Exact Expiry Date", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView.builder(
                              itemCount: filteredMembers.length,
                              itemBuilder: (context, index) {
                                final member = filteredMembers[index];
                                final daysLeft = _calculateDaysLeft(member['expiry_date']);

                                String statusText = "ACTIVE";
                                Color statusBg = Colors.green[50]!;
                                Color statusFg = Colors.green[700]!;

                                // STRICT RULE: Due Soon is only triggered if 1 to 30 days are left! 
                                // (Expired if <= 0, Active/Safe if > 30)
                                if (daysLeft <= 0) {
                                  statusText = "EXPIRED";
                                  statusBg = Colors.red[50]!;
                                  statusFg = Colors.red[700]!;
                                } else if (daysLeft <= 30) {
                                  statusText = "DUE SOON";
                                  statusBg = Colors.amber[50]!;
                                  statusFg = Colors.amber[800]!;
                                }

                                return InkWell(
                                  onTap: () {
                                    setState(() => _selectedMember = member);
                                    _fetchMemberAttendance(member['name'] ?? '');
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    margin: const EdgeInsets.only(bottom: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: daysLeft <= 0 ? Colors.red[200]! : daysLeft <= 30 ? Colors.amber[300]! : Colors.grey[100]!,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: Row(
                                            children: [
                                              if (daysLeft <= 30 && daysLeft > 0)
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  margin: const EdgeInsets.only(right: 8),
                                                  decoration: const BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Colors.amber,
                                                  ),
                                                ),
                                              Text(member['name'] ?? '', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: primaryColor)),
                                            ],
                                          ),
                                        ),
                                        Expanded(flex: 1, child: Text(member['roll_no'] ?? 'ADM-1001', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]))),
                                        Expanded(flex: 2, child: Text(member['phone'] ?? '', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]))),
                                        Expanded(flex: 2, child: Text(member['plan'] ?? 'Gold Plan', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey[800]))),
                                        Expanded(
                                          flex: 1,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(4)),
                                            child: Text(statusText, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusFg)),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            member['expiry_date'] ?? '12 Nov 2026',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: daysLeft <= 0 ? Colors.red : daysLeft <= 30 ? Colors.amber[800] : primaryColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
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

  Widget _buildMemberProfileView() {
    final member = _selectedMember!;
    const primaryColor = Color(0xFF0F172A);
    final daysLeft = _calculateDaysLeft(member['expiry_date']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Welcome back, Admin", style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => setState(() => _selectedMember = null),
                      icon: const Icon(Icons.arrow_back_rounded, color: primaryColor, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    Text("04 MEMBER PROFILE", style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: primaryColor, letterSpacing: 0.5)),
                  ],
                ),
                Text("Manage your gym operations at a glance", style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
            Text("APEX FITNESS", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: primaryColor, letterSpacing: 1.0)),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("MEMBER PROFILE", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 0.8)),
                const SizedBox(height: 12),
                
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF0F172A)),
                            child: Center(
                              child: Text(
                                (member['name'] ?? 'U').substring(0, 1).toUpperCase(),
                                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(member['name'] ?? '', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text("Roll No • ${member['roll_no'] ?? 'ADM-1001'}", style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500])),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: daysLeft <= 0 ? Colors.red[50] : daysLeft <= 30 ? Colors.amber[50] : Colors.green[50],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      daysLeft <= 0 ? "EXPIRED" : daysLeft <= 30 ? "DUE SOON" : "ACTIVE",
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: daysLeft <= 0 ? Colors.red[700] : daysLeft <= 30 ? Colors.amber[800] : Colors.green[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () => _showEditMemberDialog(member),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text("Edit member", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: () => _showDeleteMemberDialog(member),
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                            tooltip: "Delete Member",
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.red[50],
                              padding: const EdgeInsets.all(12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 260,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("CONTACT", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 0.8)),
                            const SizedBox(height: 6),
                            Text(member['phone'] ?? '+91 --', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: primaryColor)),
                            const SizedBox(height: 16),
                            Text("MEMBERSHIP", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 0.8)),
                            const SizedBox(height: 6),
                            Text(member['plan'] ?? 'Gold Plan', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: primaryColor)),
                            const SizedBox(height: 16),
                            Text("EXPIRY DATE", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 0.8)),
                            const SizedBox(height: 6),
                            Text(member['expiry_date'] ?? '12 Nov 2026', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: daysLeft <= 0 ? Colors.red : primaryColor)),
                          ],
                        ),
                      ),
                      const VerticalDivider(width: 32, thickness: 1),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _buildProfileTab("ATTENDANCE HISTORY", 0),
                                const SizedBox(width: 32),
                                _buildProfileTab("PAYMENT LEDGER", 1),
                                const SizedBox(width: 32),
                                _buildProfileTab("TRAINER NOTES", 2),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                              child: Row(
                                children: [
                                  Expanded(flex: 2, child: Text(_profileTabIdx == 0 ? "Time In" : _profileTabIdx == 1 ? "Receipt ID" : "Date", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
                                  Expanded(flex: 3, child: Text(_profileTabIdx == 0 ? "Fingerprint Scan Event" : _profileTabIdx == 1 ? "Plan Expiry" : "Note", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
                                  Expanded(flex: 2, child: Text(_profileTabIdx == 0 ? "Status" : _profileTabIdx == 1 ? "Amount / Delete" : "Author", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),

                            Expanded(
                              child: _profileTabIdx == 0
                                  ? (_isLoadingProfileAttendance
                                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
                                      : _memberAttendance.isEmpty
                                          ? Center(child: Text("No attendance records found.", style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 13)))
                                          : ListView.builder(
                                              itemCount: _memberAttendance.length,
                                              itemBuilder: (context, index) {
                                                final log = _memberAttendance[index];
                                                return _buildProfileRow(
                                                  log['time_in'] ?? 'Recent',
                                                  'Checked In',
                                                  log['status'] ?? 'CHECK-IN',
                                                );
                                              },
                                            ))
                                  : _profileTabIdx == 1
                                      ? ListView.builder(
                                          itemCount: _paymentLedger.length,
                                          itemBuilder: (context, index) {
                                            final txn = _paymentLedger[index];
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[100]!))),
                                              child: Row(
                                                children: [
                                                  Expanded(flex: 2, child: Text(txn['id'] ?? '', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)))),
                                                  Expanded(flex: 3, child: Text("Expires: ${member['expiry_date'] ?? '12 Nov 2026'}", style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]))),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Text(txn['amount'] ?? '', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500)),
                                                        IconButton(
                                                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                                          tooltip: "Delete Payment Record",
                                                          onPressed: () {
                                                            setState(() {
                                                              _paymentLedger.removeAt(index);
                                                            });
                                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment record deleted.")));
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        )
                                      : ListView(
                                          children: [
                                            _buildProfileRow("01 Oct 2026", "No active coaching notes.", "Coach"),
                                          ],
                                        ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileTab(String title, int index) {
    final isActive = _profileTabIdx == index;
    return InkWell(
      onTap: () => setState(() => _profileTabIdx = index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isActive ? const Color(0xFF0F172A) : Colors.grey[400],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileRow(String col1, String col2, String col3) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[100]!))),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(col1, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)))),
          Expanded(flex: 3, child: Text(col2, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]))),
          Expanded(flex: 2, child: Text(col3, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}