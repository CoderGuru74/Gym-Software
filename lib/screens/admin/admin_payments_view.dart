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

  List<dynamic> _payments = [];
  List<dynamic> _members = [];
  List<dynamic> _plans = [];

  bool _isLoading = true;
  bool _isSavingPayment = false;
  String? _plansError;

  late DateTime _selectedMonth;
  int? _selectedDayOfMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
    _selectedDayOfMonth = null;
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

      final plansData = (results[2] as List<dynamic>)
          .map((plan) => Map<String, dynamic>.from(plan as Map))
          .toList();

      if (!mounted) return;
      setState(() {
        _payments = results[0] as List<dynamic>;
        _members = results[1] as List<dynamic>;
        _plans = plansData;
        _plansError = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _plansError =
            'Unable to load payment data or active membership plans: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading payment data: $e')),
      );
    }
  }

  int _daysInMonth(DateTime month) {
    return DateTime(month.year, month.month + 1, 0).day;
  }

  String _monthYearLabel(DateTime month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[month.month - 1]} ${month.year}';
  }

  String _shortDateLabel(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  /// Extracts the actual date the payment was made from the payment record.
  DateTime? _extractPaymentCollectedDate(dynamic payment) {
    final candidates = [
      payment['payment_date'],
      payment['paid_date'],
      payment['created_at'],
      payment['date'],
    ];

    for (final raw in candidates) {
      if (raw == null) continue;
      final str = raw.toString().trim();
      if (str.isEmpty) continue;
      final parsed = DateTime.tryParse(str);
      if (parsed != null) return parsed.toLocal();
    }

    return null;
  }

  List<dynamic> get _filteredPayments {
    return _payments.where((payment) {
      final paidDate = _extractPaymentCollectedDate(payment);
      if (paidDate == null) return false;

      if (paidDate.year != _selectedMonth.year ||
          paidDate.month != _selectedMonth.month) {
        return false;
      }

      if (_selectedDayOfMonth != null && paidDate.day != _selectedDayOfMonth) {
        return false;
      }

      return true;
    }).toList();
  }

  double get _filteredTotalAmount {
    double sum = 0;
    for (final p in _filteredPayments) {
      final raw = p['amount'];
      if (raw is num) {
        sum += raw.toDouble();
      } else {
        sum += double.tryParse((raw ?? '').toString()) ?? 0.0;
      }
    }
    return sum;
  }

  Map<int, int> get _dailyPaymentCountsInSelectedMonth {
    final Map<int, int> counts = {};
    for (final payment in _payments) {
      final paidDate = _extractPaymentCollectedDate(payment);
      if (paidDate != null &&
          paidDate.year == _selectedMonth.year &&
          paidDate.month == _selectedMonth.month) {
        counts[paidDate.day] = (counts[paidDate.day] ?? 0) + 1;
      }
    }
    return counts;
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

  Map<String, dynamic> _findPlanById(String? planId) {
    if (planId != null) {
      for (final raw in _plans) {
        final map = Map<String, dynamic>.from(raw as Map);
        if (map['id']?.toString() == planId) {
          return map;
        }
      }
    }
    return Map<String, dynamic>.from(_plans.first as Map);
  }

  Future<bool> _insertPayment({
    required String memberName,
    required String planName,
    required double amount,
    required String dueDate,
    required String paymentDate,
  }) async {
    try {
      await _supabaseService.client.from('payments').insert({
        'member_name': memberName,
        'plan': planName,
        'amount': amount,
        'due_date': dueDate,
        'payment_date': paymentDate,
      });
      return true;
    } catch (e) {
      if (!e.toString().contains('PGRST204')) rethrow;
      await _supabaseService.client.from('payments').insert({
        'member_name': memberName,
        'plan': planName,
        'amount': amount,
        'due_date': dueDate,
      });
      return false;
    }
  }

  void _showDeletePaymentDialog(Map<String, dynamic> payment) {
    final rootMessenger = ScaffoldMessenger.of(context);

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
            onPressed: () => Navigator.of(dialogContext).pop(),
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
                  Navigator.of(dialogContext).pop();
                }
                await _fetchData();

                rootMessenger.showSnackBar(
                  const SnackBar(
                    content: Text("Payment record deleted successfully!"),
                  ),
                );
              } catch (e) {
                rootMessenger.showSnackBar(
                  SnackBar(content: Text("Error deleting payment: $e")),
                );
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

  void _showCollectPaymentDialog() {
    final rootMessenger = ScaffoldMessenger.of(context);

    if (_plans.isEmpty) {
      rootMessenger.showSnackBar(
        SnackBar(
          content: Text(
            _plansError ??
                'No active membership plans found. Add or activate a plan in Settings first.',
          ),
        ),
      );
      return;
    }

    final Map<String, dynamic> memberOptions = {};
    for (int i = 0; i < _members.length; i++) {
      final m = Map<String, dynamic>.from(_members[i] as Map);
      final name = (m['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      final key = (m['id']?.toString().trim().isNotEmpty ?? false)
          ? m['id'].toString()
          : '${name}_$i';
      memberOptions[key] = m;
    }

    String? selectedMemberKey;
    final firstPlanMap = Map<String, dynamic>.from(_plans.first as Map);
    String? selectedPlanId = firstPlanMap['id']?.toString();

    final amountController = TextEditingController(
      text: _planPrice(firstPlanMap).toStringAsFixed(2),
    );

    final now = DateTime.now();
    DateTime selectedPaidDate =
        _selectedDayOfMonth != null && _selectedDayOfMonth! <= _daysInMonth(_selectedMonth)
            ? DateTime(_selectedMonth.year, _selectedMonth.month, _selectedDayOfMonth!)
            : DateTime(now.year, now.month, now.day);
    final paidDateController = TextEditingController(
      text: _formatDate(selectedPaidDate),
    );

    DateTime selectedExpiryDate = selectedPaidDate.add(
      Duration(days: _planValidityDays(firstPlanMap)),
    );
    final dueDateController = TextEditingController(
      text: _formatDate(selectedExpiryDate),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (stfContext, setDialogState) => AlertDialog(
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
                    value: selectedMemberKey,
                    dropdownColor: const Color(0xFF2A2A32),
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration("Select Member"),
                    hint: Text(
                      "Choose member",
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                    items: memberOptions.entries
                        .map<DropdownMenuItem<String>>((entry) {
                      final member =
                          Map<String, dynamic>.from(entry.value as Map);
                      final name = (member['name'] ?? '').toString();
                      final phone = (member['phone'] ?? '').toString();
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(
                          phone.isEmpty ? name : '$name ($phone)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: _isSavingPayment
                        ? null
                        : (value) {
                            setDialogState(() => selectedMemberKey = value);
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
                    items: _plans.map<DropdownMenuItem<String>>((rawPlan) {
                      final plan = Map<String, dynamic>.from(rawPlan as Map);
                      final id = plan['id'].toString();
                      final name =
                          (plan['plan_name'] ?? 'Unnamed Plan').toString();
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
                    onChanged: _isSavingPayment
                        ? null
                        : (value) {
                            if (value == null) return;
                            final plan = _findPlanById(value);

                            setDialogState(() {
                              selectedPlanId = value;
                              amountController.text =
                                  _planPrice(plan).toStringAsFixed(2);
                              selectedExpiryDate = selectedPaidDate.add(
                                Duration(days: _planValidityDays(plan)),
                              );
                              dueDateController.text =
                                  _formatDate(selectedExpiryDate);
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
                    enabled: !_isSavingPayment,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration("Amount (₹)"),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: paidDateController,
                    readOnly: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration("Payment Made Date").copyWith(
                      suffixIcon: const Icon(
                        Icons.event_available_rounded,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                    onTap: _isSavingPayment
                        ? null
                        : () async {
                            final pickedDate = await showDatePicker(
                              context: stfContext,
                              initialDate: selectedPaidDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                              builder: (pickerContext, child) {
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

                            if (pickedDate != null && dialogContext.mounted) {
                              setDialogState(() {
                                selectedPaidDate = pickedDate;
                                paidDateController.text =
                                    _formatDate(pickedDate);
                                if (selectedPlanId != null) {
                                  final plan = _findPlanById(selectedPlanId);
                                  selectedExpiryDate = selectedPaidDate.add(
                                    Duration(days: _planValidityDays(plan)),
                                  );
                                  dueDateController.text =
                                      _formatDate(selectedExpiryDate);
                                }
                              });
                            }
                          },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: dueDateController,
                    readOnly: true,
                    style: const TextStyle(color: Colors.white),
                    decoration:
                        _inputDecoration("Due Date / Expiry Date").copyWith(
                      suffixIcon: const Icon(
                        Icons.calendar_month_rounded,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                    onTap: _isSavingPayment
                        ? null
                        : () async {
                            final pickedDate = await showDatePicker(
                              context: stfContext,
                              initialDate: selectedExpiryDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                              builder: (pickerContext, child) {
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

                            if (pickedDate != null && dialogContext.mounted) {
                              setDialogState(() {
                                selectedExpiryDate = pickedDate;
                                dueDateController.text =
                                    _formatDate(pickedDate);
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
                  : () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      Navigator.of(dialogContext).pop();
                    },
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: _isSavingPayment
                  ? null
                  : () async {
                      if (selectedMemberKey == null ||
                          !memberOptions.containsKey(selectedMemberKey)) {
                        rootMessenger.showSnackBar(
                          const SnackBar(
                            content: Text('Please select a member.'),
                          ),
                        );
                        return;
                      }

                      final selectedMember = Map<String, dynamic>.from(
                        memberOptions[selectedMemberKey] as Map,
                      );
                      final selectedMemberName =
                          (selectedMember['name'] ?? '').toString().trim();

                      final amountNum =
                          double.tryParse(amountController.text.trim());
                      if (amountNum == null || amountNum <= 0) {
                        rootMessenger.showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid amount.'),
                          ),
                        );
                        return;
                      }

                      if (selectedPlanId == null) return;

                      final plan = _findPlanById(selectedPlanId);
                      final planName =
                          (plan['plan_name'] ?? 'Unnamed Plan').toString();

                      setDialogState(() => _isSavingPayment = true);
                      try {
                        final savedWithPaymentDate = await _insertPayment(
                          memberName: selectedMemberName,
                          planName: planName,
                          amount: amountNum,
                          dueDate: dueDateController.text.trim(),
                          paymentDate: paidDateController.text.trim(),
                        );

                        FocusManager.instance.primaryFocus?.unfocus();

                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }

                        await _fetchData();

                        rootMessenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              savedWithPaymentDate
                                  ? "Payment collected and saved for ${paidDateController.text.trim()}!"
                                  : "Payment saved! Add a 'payment_date' (date) column in Supabase payments table so each payment stays on its exact paid date.",
                            ),
                            backgroundColor:
                                savedWithPaymentDate ? Colors.green : Colors.orange,
                          ),
                        );
                      } catch (e) {
                        if (dialogContext.mounted) {
                          setDialogState(() => _isSavingPayment = false);
                        }
                        rootMessenger.showSnackBar(
                          SnackBar(
                            content: Text("Error saving payment: $e"),
                            backgroundColor: Colors.red,
                          ),
                        );
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
      if (mounted) {
        setState(() => _isSavingPayment = false);
      }
      Future.delayed(const Duration(milliseconds: 350), () {
        amountController.dispose();
        paidDateController.dispose();
        dueDateController.dispose();
      });
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
    final totalDays = _daysInMonth(_selectedMonth);
    final dailyCounts = _dailyPaymentCountsInSelectedMonth;
    final visiblePayments = _filteredPayments;
    final today = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 12,
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
                  "Select any month or day below to see who made a payment on that date",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
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
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _selectedMonth = DateTime(
                                _selectedMonth.year,
                                _selectedMonth.month - 1,
                                1,
                              );
                              _selectedDayOfMonth = null;
                            });
                          },
                          icon: const Icon(
                            Icons.chevron_left_rounded,
                            size: 20,
                            color: primaryColor,
                          ),
                          tooltip: "Previous Month",
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          constraints: const BoxConstraints(),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_month_rounded,
                                size: 15,
                                color: primaryColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _monthYearLabel(_selectedMonth),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _selectedMonth = DateTime(
                                _selectedMonth.year,
                                _selectedMonth.month + 1,
                                1,
                              );
                              _selectedDayOfMonth = null;
                            });
                          },
                          icon: const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: primaryColor,
                          ),
                          tooltip: "Next Month",
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ChoiceChip(
                    label: Text(
                      "All Days (${_monthYearLabel(_selectedMonth)})",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _selectedDayOfMonth == null
                            ? Colors.white
                            : primaryColor,
                      ),
                    ),
                    selected: _selectedDayOfMonth == null,
                    selectedColor: primaryColor,
                    backgroundColor: const Color(0xFFF1F5F9),
                    onSelected: (_) {
                      setState(() => _selectedDayOfMonth = null);
                    },
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Text(
                      "${visiblePayments.length} ${visiblePayments.length == 1 ? 'Payment' : 'Payments'}  •  ₹ ${_filteredTotalAmount.toStringAsFixed(0)}",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF047857),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: totalDays,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, idx) {
                    final day = idx + 1;
                    final isSelected = _selectedDayOfMonth == day;
                    final count = dailyCounts[day] ?? 0;
                    final isToday = today.year == _selectedMonth.year &&
                        today.month == _selectedMonth.month &&
                        today.day == day;

                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        setState(() {
                          _selectedDayOfMonth = isSelected ? null : day;
                        });
                      },
                      child: Container(
                        width: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primaryColor
                              : count > 0
                                  ? const Color(0xFFE0F2FE)
                                  : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? primaryColor
                                : isToday
                                    ? const Color(0xFF0284C7)
                                    : count > 0
                                        ? const Color(0xFF7DD3FC)
                                        : const Color(0xFFE2E8F0),
                            width: isToday ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              day.toString().padLeft(2, '0'),
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? Colors.white
                                    : count > 0
                                        ? const Color(0xFF0369A1)
                                        : const Color(0xFF475569),
                              ),
                            ),
                            if (count > 0)
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF38BDF8)
                                      : const Color(0xFF10B981),
                                  shape: BoxShape.circle,
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
        const SizedBox(height: 16),
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
                : visiblePayments.isEmpty
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
                              _selectedDayOfMonth != null
                                  ? "No payments recorded on ${_selectedDayOfMonth.toString().padLeft(2, '0')} ${_monthYearLabel(_selectedMonth)}."
                                  : "No payment transactions recorded in ${_monthYearLabel(_selectedMonth)}.",
                              style: GoogleFonts.inter(
                                color: Colors.grey[600],
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Select another day above or click 'Collect Payment' to record one.",
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
                                    "Paid On",
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
                              itemCount: visiblePayments.length,
                              itemBuilder: (context, index) {
                                final payment = visiblePayments[index];
                                final paidDate =
                                    _extractPaymentCollectedDate(payment);
                                final paidDateStr = paidDate != null
                                    ? _shortDateLabel(paidDate)
                                    : 'N/A';

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
                                          paidDateStr,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF334155),
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