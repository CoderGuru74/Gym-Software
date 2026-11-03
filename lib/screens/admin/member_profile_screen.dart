import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MemberProfileScreen extends StatefulWidget {
  final String memberName;
  final String plan;
  final String status;
  final File? profileImage;

  const MemberProfileScreen({
    super.key,
    required this.memberName,
    required this.plan,
    this.status = "ACTIVE",
    this.profileImage,
  });

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> {
  int _selectedTab = 0; // 0 = Attendance History, 1 = Payment Ledger, 2 = Trainer Notes

  // Mutable profile fields
  late String _currentName;
  late String _currentPlan;
  late String _currentStatus;
  final String _memberId = "AFX-02418";
  final String _contactNumber = "+91 98765 43210";
  final String _expiryDate = "14 Nov 2026";

  @override
  void initState() {
    super.initState();
    _currentName = widget.memberName;
    _currentPlan = widget.plan;
    _currentStatus = widget.status;
  }

  // Opens a comprehensive Edit Member Dialog for all fields
  void _showEditMemberDialog() {
    final TextEditingController nameController = TextEditingController(text: _currentName);
    final TextEditingController contactController = TextEditingController(text: _contactNumber);
    final TextEditingController expiryController = TextEditingController(text: _expiryDate);
    String selectedPlan = _currentPlan;
    String selectedStatus = _currentStatus;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            "Edit Member Profile",
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Update all member details below:",
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: "Member Name",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contactController,
                  decoration: const InputDecoration(
                    labelText: "Contact Number",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedPlan,
                  decoration: const InputDecoration(
                    labelText: "Membership Plan",
                    border: OutlineInputBorder(),
                  ),
                  items: ["Gold Plan", "Silver Plan", "Premium", "Standard Plan"]
                      .map((plan) => DropdownMenuItem(
                            value: plan,
                            child: Text(plan),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        selectedPlan = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: const InputDecoration(
                    labelText: "Status",
                    border: OutlineInputBorder(),
                  ),
                  items: ["ACTIVE", "EXPIRED", "DUE SOON"]
                      .map((status) => DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        selectedStatus = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: expiryController,
                  decoration: const InputDecoration(
                    labelText: "Expiry Date (e.g., 14 Nov 2026)",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;

                setState(() {
                  _currentName = nameController.text.trim();
                  _currentPlan = selectedPlan;
                  _currentStatus = selectedStatus;
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("All member details updated successfully!")),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
              ),
              child: const Text("Save Changes"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFF0F4F8);
    const primaryColor = Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TOP HEADER & BACK BUTTON
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Welcome back, Admin",
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "04 MEMBER PROFILE",
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: primaryColor,
                          ),
                        ),
                        Text(
                          "Manage your gym operations at a glance",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  "APEX FITNESS",
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // MAIN CONTENT CARD CONTAINER
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "MEMBER PROFILE",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[500],
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // MEMBER BANNER BOX
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          widget.profileImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(28),
                                  child: Image.file(widget.profileImage!, width: 56, height: 56, fit: BoxFit.cover),
                                )
                              : CircleAvatar(
                                  radius: 28,
                                  backgroundColor: primaryColor,
                                  child: Text(
                                    _currentName.isNotEmpty ? _currentName[0].toUpperCase() : "M",
                                    style: GoogleFonts.inter(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                          const SizedBox(width: 20),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentName,
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    "Member ID • $_memberId",
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _currentStatus == "ACTIVE" ? Colors.green[600] : Colors.red[600],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _currentStatus,
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: _showEditMemberDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              "Edit member",
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // LOWER SECTION: LEFT INFO + RIGHT TABBED TABLES
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // LEFT COLUMN: Contact, Membership & Expiry details
                          SizedBox(
                            width: 240,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDetailItem("CONTACT", _contactNumber),
                                const SizedBox(height: 24),
                                _buildDetailItem("MEMBERSHIP", _currentPlan),
                                const SizedBox(height: 24),
                                _buildDetailItem("EXPIRY DATE", _expiryDate),
                              ],
                            ),
                          ),
                          const VerticalDivider(width: 48, thickness: 1),

                          // RIGHT COLUMN: Tabs + Data Table
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _buildTabButton("ATTENDANCE HISTORY", 0),
                                    const SizedBox(width: 32),
                                    _buildTabButton("PAYMENT LEDGER", 1),
                                    const SizedBox(width: 32),
                                    _buildTabButton("TRAINER NOTES", 2),
                                  ],
                                ),
                                const Divider(height: 24),
                                Expanded(
                                  child: _selectedTab == 0
                                      ? _buildAttendanceTable()
                                      : _selectedTab == 1
                                          ? _buildPaymentLedgerTable()
                                          : _buildTrainerNotesView(),
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
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.grey[500],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton(String title, int index) {
    bool isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? const Color(0xFF1E293B) : Colors.grey[400],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceTable() {
    final history = [
      {"date": "09 Oct 2026", "activity": "Morning workout", "status": "Checked in"},
      {"date": "08 Oct 2026", "activity": "Strength training", "status": "Checked in"},
      {"date": "07 Oct 2026", "activity": "Evening workout", "status": "Checked in"},
      {"date": "05 Oct 2026", "activity": "Cardio session", "status": "Checked in"},
      {"date": "03 Oct 2026", "activity": "Morning workout", "status": "Checked in"},
    ];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Expanded(child: Text("Date", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
              Expanded(child: Text("Activity", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
              Expanded(child: Text("Status", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final row = history[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(row["date"]!, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700]))),
                    Expanded(child: Text(row["activity"]!, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF1E293B)))),
                    Expanded(child: Text(row["status"]!, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]))),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentLedgerTable() {
    return Center(
      child: Text(
        "Payment records and history appear here.",
        style: GoogleFonts.inter(color: Colors.grey[500]),
      ),
    );
  }

  Widget _buildTrainerNotesView() {
    return Center(
      child: Text(
        "Trainer notes and custom workout assignments appear here.",
        style: GoogleFonts.inter(color: Colors.grey[500]),
      ),
    );
  }
}