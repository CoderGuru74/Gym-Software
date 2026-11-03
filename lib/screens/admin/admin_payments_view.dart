import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/supabase_service.dart';

class AdminPaymentsView extends StatefulWidget {
  const AdminPaymentsView({super.key});

  @override
  State<AdminPaymentsView> createState() => _AdminPaymentsViewState();
}

class _AdminPaymentsViewState extends State<AdminPaymentsView> {
  final _supabaseService = SupabaseService();
  List _payments = [];
  List _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final paymentsData = await _supabaseService.getPayments();
      final membersData = await _supabaseService.getMembers();
      setState(() {
        _payments = paymentsData;
        _members = membersData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // Delete Payment Confirmation Dialog
  void _showDeletePaymentDialog(Map<String, dynamic> payment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Delete Payment Record", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text(
          "Are you sure you want to delete this payment record for '${payment['member_name']}'? This action cannot be undone.",
          style: GoogleFonts.inter(color: Colors.grey[300], fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              try {
                // Delete from Supabase payments table
                await _supabaseService.client.from('payments').delete().eq('id', payment['id']);
                Navigator.pop(context);
                await _fetchData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment record deleted successfully!")));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error deleting payment: $e")));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
            child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Dialog to Collect Payment & Select Member with a Calendar Date Picker
  void _showCollectPaymentDialog() {
    String? selectedMemberName;
    String selectedPlan = 'Gold Plan';
    final TextEditingController amountController = TextEditingController();
    
    DateTime selectedDate = DateTime.now().add(const Duration(days: 30));
    final TextEditingController dueDateController = TextEditingController(
      text: "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}",
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            "Collect Payment",
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedMemberName,
                    dropdownColor: const Color(0xFF2A2A32),
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration("Select Member"),
                    hint: Text("Choose member", style: TextStyle(color: Colors.grey[400])),
                    items: _members.isEmpty
                        ? []
                        : _members.map<DropdownMenuItem<String>>((member) {
                            return DropdownMenuItem<String>(
                              value: member['name'].toString(),
                              child: Text("${member['name']} (${member['phone']})"),
                            );
                          }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedMemberName = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration("Amount (₹)"),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: dueDateController,
                    readOnly: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration("Due Date / Expiry Date").copyWith(
                      suffixIcon: const Icon(Icons.calendar_month_rounded, color: Color(0xFF38BDF8)),
                    ),
                    onTap: () async {
                      final DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: Color(0xFF38BDF8),
                                onPrimary: Colors.black,
                                surface: Color(0xFF1E1E24),
                                onSurface: Colors.white,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );

                      if (pickedDate != null) {
                        setDialogState(() {
                          selectedDate = pickedDate;
                          dueDateController.text = "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedMemberName == null || amountController.text.trim().isEmpty) {
                  return;
                }

                try {
                  final amountNum = double.tryParse(amountController.text.trim()) ?? 0.0;
                  
                  await _supabaseService.client.from('payments').insert({
                    'member_name': selectedMemberName,
                    'plan': selectedPlan,
                    'amount': amountNum,
                    'due_date': dueDateController.text.trim(),
                  });

                  Navigator.pop(context);
                  _fetchData();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Payment collected and saved successfully!")),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error saving payment: $e")),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Save Payment", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
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
    const primaryColor = Color(0xFF0F172A);

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
                  "PAYMENTS & TRANSACTIONS",
                  style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: primaryColor),
                ),
                Text(
                  "Track member subscriptions, dues, and record new payments",
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  onPressed: _fetchData,
                  icon: const Icon(Icons.refresh_rounded, color: primaryColor),
                  tooltip: "Refresh Payments",
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _showCollectPaymentDialog,
                  icon: const Icon(Icons.add_card_rounded, size: 16),
                  label: const Text("Collect Payment"),
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
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5)),
              ],
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
                : _payments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_rounded, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              "No payment transactions recorded yet.",
                              style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Click 'Collect Payment' above to record your first transaction.",
                              style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 13),
                            ),
                          ],
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
                                Expanded(flex: 2, child: Text("Plan", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
                                Expanded(flex: 2, child: Text("Amount", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
                                Expanded(flex: 2, child: Text("Due / Expiry Date", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
                                Expanded(flex: 1, child: Text("Action", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _payments.length,
                              itemBuilder: (context, index) {
                                final payment = _payments[index];
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
                                      Expanded(flex: 2, child: Text(payment['member_name'] ?? '', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: primaryColor))),
                                      Expanded(flex: 2, child: Text(payment['plan'] ?? '', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]))),
                                      Expanded(flex: 2, child: Text("₹ ${payment['amount'] ?? 0}", style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.green[700]))),
                                      Expanded(flex: 2, child: Text(payment['due_date'] ?? '', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]))),
                                      Expanded(
                                        flex: 1,
                                        child: IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                          tooltip: "Delete Payment",
                                          onPressed: () => _showDeletePaymentDialog(payment),
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