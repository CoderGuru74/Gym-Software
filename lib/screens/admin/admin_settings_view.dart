import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MembershipPlanItem {
  final String planName;
  final String duration;
  final String price;
  final String status;

  MembershipPlanItem({
    required this.planName,
    required this.duration,
    required this.price,
    required this.status,
  });
}

class AdminSettingsView extends StatefulWidget {
  const AdminSettingsView({super.key});

  @override
  State<AdminSettingsView> createState() => _AdminSettingsViewState();
}

class _AdminSettingsViewState extends State<AdminSettingsView> {
  // Membership Plans List
  final List<MembershipPlanItem> _plans = [
    MembershipPlanItem(planName: "Silver", duration: "1 month", price: "₹ 1,800", status: "Active"),
    MembershipPlanItem(planName: "Gold", duration: "3 months", price: "₹ 6,500", status: "Active"),
    MembershipPlanItem(planName: "Premium", duration: "6 months", price: "₹ 12,000", status: "Active"),
    MembershipPlanItem(planName: "Annual", duration: "12 months", price: "₹ 22,000", status: "Active"),
    MembershipPlanItem(planName: "Student", duration: "1 month", price: "₹ 1,200", status: "Active"),
  ];

  // Dialog to Add a New Membership Plan
  void _showAddPlanDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController durationController = TextEditingController();
    final TextEditingController priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: Text("Add New Membership Plan", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Plan Name (e.g. VIP)", labelStyle: TextStyle(color: Colors.grey), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: durationController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Duration (e.g. 3 months)", labelStyle: TextStyle(color: Colors.grey), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Price (e.g. ₹ 5,000)", labelStyle: TextStyle(color: Colors.grey), border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty || priceController.text.trim().isEmpty) return;
              setState(() {
                _plans.add(
                  MembershipPlanItem(
                    planName: nameController.text.trim(),
                    duration: durationController.text.trim().isEmpty ? "1 month" : durationController.text.trim(),
                    price: priceController.text.trim(),
                    status: "Active",
                  ),
                );
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("New membership plan added successfully!")),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8), foregroundColor: Colors.black),
            child: const Text("Add Plan", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Delete Plan Function
  void _deletePlan(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: Text("Delete Plan", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text("Are you sure you want to delete this membership plan?", style: GoogleFonts.inter(color: Colors.grey[300])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _plans.removeAt(index);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Membership plan deleted successfully!")),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white),
            child: const Text("Delete", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0F172A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "GYM SETTINGS & PLAN MANAGEMENT",
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey[500]),
                ),
                const SizedBox(height: 24),

                // TWO COLUMNS: LEFT GYM INFO DISPLAY + RIGHT MEMBERSHIP PLANS
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // LEFT COLUMN: READ-ONLY GYM INFORMATION & ASSET LOGO DISPLAY
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.asset(
                                        'assets/images/muscle.jpeg',
                                        width: 52,
                                        height: 52,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          width: 52,
                                          height: 52,
                                          decoration: BoxDecoration(
                                            color: primaryColor,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Center(
                                            child: Icon(Icons.fitness_center_rounded, color: Color(0xFF38BDF8), size: 26),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "THE MUSCLE GYM",
                                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: primaryColor, letterSpacing: 0.5),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "Official Gym Profile",
                                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 28),
                                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                                const SizedBox(height: 24),

                                _buildInfoItem("Gym Name", "The Muscle Gym"),
                                const SizedBox(height: 20),
                                _buildInfoItem("Address", "Plot 24, Main Road, Patna, Bihar"),
                                const SizedBox(height: 20),
                                _buildInfoItem("Contact Phone", "+91 98765 00000"),
                                const SizedBox(height: 20),
                                _buildInfoItem("Support Email", "hello@themusclegym.in"),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 32),

                      // RIGHT COLUMN: MEMBERSHIP PLANS TABLE WITH DELETE OPTION
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "MEMBERSHIP PLANS",
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: primaryColor),
                              ),
                              const SizedBox(height: 16),

                              // Table Header
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(flex: 2, child: Text("Plan name", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
                                    Expanded(flex: 2, child: Text("Duration", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
                                    Expanded(flex: 2, child: Text("Price", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
                                    Expanded(flex: 1, child: Text("Status", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
                                    const SizedBox(width: 40),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Table Rows List with Delete Action
                              Expanded(
                                child: ListView.builder(
                                  itemCount: _plans.length,
                                  itemBuilder: (context, index) {
                                    final plan = _plans[index];
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      margin: const EdgeInsets.only(bottom: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey[100]!),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(flex: 2, child: Text(plan.planName, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: primaryColor))),
                                          Expanded(flex: 2, child: Text(plan.duration, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]))),
                                          Expanded(flex: 2, child: Text(plan.price, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: primaryColor))),
                                          Expanded(flex: 1, child: Text(plan.status, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green[700]))),
                                          IconButton(
                                            onPressed: () => _deletePlan(index),
                                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                            tooltip: "Delete Plan",
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Add New Plan Button
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton.icon(
                                  onPressed: _showAddPlanDialog,
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text("Add new plan"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
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
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[500])),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
        ),
      ],
    );
  }
}