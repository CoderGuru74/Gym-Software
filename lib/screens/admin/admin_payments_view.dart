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
  List<Map<String, dynamic>> _plans = [];

  bool _isLoading = true;
  bool _isSavingPayment = false;
  String? _plansError;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final results = await Future.wait([
        _supabaseService.getPayments(),
        _supabaseService.getMembers(),
        _supabaseService.client
            .from('membership_plans')
            .select()
            .eq('status', 'Active')
            .order('created_at', ascending: false),
      ]);

      final plansData = (results[2] as List)
          .map((plan) => Map<String, dynamic>.from(plan as Map))
          .toList();

      if (!mounted) return;
      setState(() {
        _payments = results[0] as List;
        _members = results[1] as List;
        _plans = plansData;
        _plansError = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _plansError = 'Unable to load payment data or active membership plans: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading payment data: $e')),
      );
    }
  }

  int _planValidityDays(Map<String, dynamic> plan) {
    final validityDays = plan['validity_days'];
    if (validityDays != null) {
      final parsed = int.tryParse(validityDays.toString());
      if (parsed != null && parsed > 0) return parsed;
    }

    final durationValue = int.tryParse(
          (plan['duration_value'] ?? '').toString(),
        ) ??
        0;
    final durationUnit = (plan['duration_unit'] ?? 'days')
        .toString()
        .toLowerCase()
        .trim();

    if (durationValue <= 0) return 30;
    switch (durationUnit) {
      case 'week':
      case 'weeks':
        return durationValue * 7;
      case 'month':
      case 'months':
        return durationValue * 30;
      case 'year':
      case 'years':
        return durationValue * 365;
      case 'day':
      case 'days':
      default:
        return durationValue;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  double _planPrice(Map<String, dynamic> plan) {
    final price = plan['price'];
    if (price is num) return price.toDouble();
    return double.tryParse((price ?? '').toString()) ?? 0.0;
  }

  // Delete Payment Confirmation Dialog
  void _showDeletePaymentDialog(Map<String, dynamic> payment) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Delete Payment Record",
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Text(
          "Are you sure you want to delete this payment record for '${payment['member_name']}'? This action cannot be undone.",
          style: GoogleFonts.inter(color: Colors.grey[300], fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _supabaseService.client
                    .from('payments')
                    .delete()
                    .eq('id', payment['id']);

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                await _fetchData();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Payment record deleted successfully!"),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error deleting payment: $e")),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
            ),
            child: const Text(
              "Delete",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Collect payment using membership plans stored in Supabase.
  void _showCollectPaymentDialog() {
    if (_plans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _plansError ??
                'No active membership plans found. Add or activate a plan in Settings first.',
          ),
        ),
      );
      return;
    }

    String? selectedMemberName;
    String? selectedPlanId = _plans.first['id']?.toString();

    final selectedPlan = _plans.firstWhere(
      (plan) => plan['id']?.toString() == selectedPlanId,
      orElse: () => _plans.first,
    );

    final amountController = TextEditingController(
      text: _planPrice(selectedPlan).toStringAsFixed(2),
    );

    DateTime selectedDate = DateTime.now().add(
      Duration(days: _planValidityDays(selectedPlan)),
    );
    final dueDateController = TextEditingController(
      text: _formatDate(selectedDate),
    );

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            "Collect Payment",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
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
                    hint: Text(
                      "Choose member",
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                    items: _members.map<DropdownMenuItem<String>>((member) {
                      final name = (member['name'] ?? '').toString();
                      final phone = (member['phone'] ?? '').toString();
                      return DropdownMenuItem<String>(
                        value: name,
                        child: Text(
                          phone.isEmpty ? name : '$name ($phone)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedMemberName = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedPlanId,
                    dropdownColor: const Color(0xFF2A2A32),
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration("Membership Plan"),
                    hint: Text(
                      "Choose active plan",
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                    items: _plans.map<DropdownMenuItem<String>>((plan) {
                      final id = plan['id'].toString();
                      final name = (plan['plan_name'] ?? 'Unnamed Plan')
                          .toString();
                      final price = _planPrice(plan);
                      final validity = _planValidityDays(plan);
                      return DropdownMenuItem<String>(
                        value: id,
                        child: Text(
                          '$name - ₹${price.toStringAsFixed(0)} ($validity days)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;

                      final plan = _plans.firstWhere(
                        (item) => item['id'].toString() == value,
                      );

                      setDialogState(() {
                        selectedPlanId = value;
                        amountController.text =
                            _planPrice(plan).toStringAsFixed(2);
                        selectedDate = DateTime.now().add(
                          Duration(days: _planValidityDays(plan)),
                        );
                        dueDateController.text = _formatDate(selectedDate);
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Plan price and expiry are filled automatically. You can edit the amount or date if needed.',
                      style: GoogleFonts.inter(
                        color: Colors.grey[400],
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration("Amount (₹)"),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: dueDateController,
                    readOnly: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration("Due Date / Expiry Date")
                        .copyWith(
                      suffixIcon: const Icon(
                        Icons.calendar_month_rounded,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                    onTap: () async {
                      final pickedDate = await showDatePicker(
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
                          dueDateController.text = _formatDate(pickedDate);
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
              onPressed: _isSavingPayment
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: _isSavingPayment
                  ? null
                  : () async {
                      if (selectedMemberName == null ||
                          selectedMemberName!.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a member.'),
                          ),
                        );
                        return;
                      }

                      final amountNum =
                          double.tryParse(amountController.text.trim());
                      if (amountNum == null || amountNum <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid amount.'),
                          ),
                        );
                        return;
                      }

                      if (selectedPlanId == null) return;

                      final plan = _plans.firstWhere(
                        (item) => item['id'].toString() == selectedPlanId,
                      );
                      final planName =
                          (plan['plan_name'] ?? 'Unnamed Plan').toString();

                      setDialogState(() => _isSavingPayment = true);
                      try {
                        await _supabaseService.client.from('payments').insert({
                          'member_name': selectedMemberName,
                          'plan': planName,
                          'amount': amountNum,
                          'due_date': dueDateController.text.trim(),
                        });

                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        await _fetchData();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Payment collected and saved successfully!",
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => _isSavingPayment = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Error saving payment: $e"),
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSavingPayment
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      "Save Payment",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    ).then((_) {
      amountController.dispose();
      dueDateController.dispose();
      if (mounted) setState(() => _isSavingPayment = false);
    });
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[400]),
      filled: true,
      fillColor: const Color(0xFF2A2A32),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF38BDF8)),
      ),
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
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: primaryColor,
                  ),
                ),
                Text(
                  "Track member subscriptions, dues, and record new payments",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  onPressed: _fetchData,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: primaryColor,
                  ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF38BDF8),
                    ),
                  )
                : _payments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_rounded,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "No payment transactions recorded yet.",
                              style: GoogleFonts.inter(
                                color: Colors.grey[600],
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Click 'Collect Payment' above to record your first transaction.",
                              style: GoogleFonts.inter(
                                color: Colors.grey[400],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    "Member Name",
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    "Plan",
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    "Amount",
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    "Due / Expiry Date",
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    "Action",
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  margin: const EdgeInsets.only(bottom: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey[100]!,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          payment['member_name'] ?? '',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          payment['plan'] ?? '',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          "₹ ${payment['amount'] ?? 0}",
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.green[700],
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          payment['due_date'] ?? '',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            color: Colors.red,
                                            size: 20,
                                          ),
                                          tooltip: "Delete Payment",
                                          onPressed: () =>
                                              _showDeletePaymentDialog(
                                            Map<String, dynamic>.from(payment),
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
