import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MembershipPlanItem {
  final int id;
  final String planName;
  final String duration;
  final String price;
  final String description;
  final List<String> features;
  final String status;

  MembershipPlanItem({
    required this.id,
    required this.planName,
    required this.duration,
    required this.price,
    this.description = '',
    this.features = const [],
    required this.status,
  });

  factory MembershipPlanItem.fromMap(Map<String, dynamic> map) {
    final rawFeatures = map['features'];
    final features = rawFeatures is List
        ? rawFeatures.map((item) => item.toString()).toList()
        : <String>[];

    final amount = double.tryParse(map['price'].toString()) ?? 0;
    final amountText = amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);

    return MembershipPlanItem(
      id: (map['id'] as num).toInt(),
      planName: map['plan_name']?.toString() ?? '',
      duration: '${map['duration_value'] ?? 1} ${map['duration_unit'] ?? 'Months'}',
      price: '₹ ${_formatPriceValue(amountText)}',
      description: map['description']?.toString() ?? '',
      features: features,
      status: map['status']?.toString() ?? 'Active',
    );
  }

  static String _formatPriceValue(String value) {
    final parts = value.split('.');
    final whole = parts[0];
    final buffer = StringBuffer();
    for (int i = 0; i < whole.length; i++) {
      final remaining = whole.length - i;
      buffer.write(whole[i]);
      if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
    }
    return parts.length > 1 && parts[1] != '00'
        ? '${buffer.toString()}.${parts[1]}'
        : buffer.toString();
  }
}

class AdminSettingsView extends StatefulWidget {
  const AdminSettingsView({super.key});

  @override
  State<AdminSettingsView> createState() => _AdminSettingsViewState();
}

class _AdminSettingsViewState extends State<AdminSettingsView> {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Starts empty. Only plans stored in Supabase are displayed.
  final List<MembershipPlanItem> _plans = [];
  bool _isLoadingPlans = true;
  String? _plansError;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    if (!mounted) return;
    setState(() {
      _isLoadingPlans = true;
      _plansError = null;
    });

    try {
      final response = await _supabase
          .from('membership_plans')
          .select(
            'id, plan_name, duration_value, duration_unit, validity_days, '
            'price, description, features, status, created_at',
          )
          .order('created_at', ascending: false);

      final plans = (response as List)
          .map((row) => MembershipPlanItem.fromMap(
                Map<String, dynamic>.from(row as Map),
              ))
          .toList();

      if (!mounted) return;
      setState(() {
        _plans
          ..clear()
          ..addAll(plans);
        _isLoadingPlans = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingPlans = false;
        _plansError = error.toString();
      });
    }
  }

  // Add a membership plan with complete details.
  void _showAddPlanDialog() {
    final nameController = TextEditingController();
    final durationController = TextEditingController(text: '1');
    final priceController = TextEditingController();
    final descriptionController = TextEditingController();
    final featuresController = TextEditingController();

    String selectedDurationUnit = 'Months';
    String selectedStatus = 'Active';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E24),
          title: Text(
            "Add New Membership Plan",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDialogLabel('Plan name *'),
                    TextFormField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      textCapitalization: TextCapitalization.words,
                      decoration: _planInputDecoration(
                        'e.g. VIP, Silver, Gold',
                        prefixIcon: Icons.card_membership,
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Please enter a plan name'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    _buildDialogLabel('Plan duration *'),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: durationController,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.number,
                            decoration: _planInputDecoration(
                              'Enter number',
                              prefixIcon: Icons.schedule,
                            ),
                            validator: (value) {
                              final number = int.tryParse(value?.trim() ?? '');
                              if (number == null || number <= 0) {
                                return 'Enter a valid duration';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: selectedDurationUnit,
                            dropdownColor: const Color(0xFF292932),
                            style: const TextStyle(color: Colors.white),
                            decoration: _planInputDecoration('Unit'),
                            items: const [
                              DropdownMenuItem(value: 'Days', child: Text('Days')),
                              DropdownMenuItem(value: 'Weeks', child: Text('Weeks')),
                              DropdownMenuItem(value: 'Months', child: Text('Months')),
                              DropdownMenuItem(value: 'Years', child: Text('Years')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() => selectedDurationUnit = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildDialogLabel('Membership price *'),
                    TextFormField(
                      controller: priceController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _planInputDecoration(
                        'e.g. 5000',
                        prefixIcon: Icons.currency_rupee,
                      ),
                      validator: (value) {
                        final price = double.tryParse(
                          (value ?? '').trim().replaceAll(',', ''),
                        );
                        if (price == null || price <= 0) {
                          return 'Enter a valid price';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildDialogLabel('Plan description'),
                    TextFormField(
                      controller: descriptionController,
                      style: const TextStyle(color: Colors.white),
                      minLines: 2,
                      maxLines: 3,
                      decoration: _planInputDecoration(
                        'Briefly describe this membership plan',
                        prefixIcon: Icons.description_outlined,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildDialogLabel('Plan features / benefits'),
                    TextFormField(
                      controller: featuresController,
                      style: const TextStyle(color: Colors.white),
                      minLines: 3,
                      maxLines: 5,
                      decoration: _planInputDecoration(
                        'Enter each feature on a new line\nExample:\nAccess to all equipment\nPersonal trainer support\nLocker facility',
                        prefixIcon: Icons.checklist,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildDialogLabel('Plan status'),
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      dropdownColor: const Color(0xFF292932),
                      style: const TextStyle(color: Colors.white),
                      decoration: _planInputDecoration('Select status'),
                      items: const [
                        DropdownMenuItem(value: 'Active', child: Text('Active')),
                        DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedStatus = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final enteredPrice = double.parse(
                  priceController.text.trim().replaceAll(',', ''),
                );
                final features = featuresController.text
                    .split('\n')
                    .map((feature) => feature.trim())
                    .where((feature) => feature.isNotEmpty)
                    .toList();

                final durationValue = int.parse(durationController.text.trim());
                final validityDays = _calculateValidityDays(
                  durationValue,
                  selectedDurationUnit,
                );

                try {
                  await _supabase.from('membership_plans').insert({
                    'plan_name': nameController.text.trim(),
                    'duration_value': durationValue,
                    'duration_unit': selectedDurationUnit,
                    'validity_days': validityDays,
                    'price': enteredPrice,
                    'description': descriptionController.text.trim(),
                    'features': features,
                    'status': selectedStatus,
                  });

                  if (!mounted) return;
                  Navigator.pop(dialogContext);
                  await _loadPlans();

                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('Membership plan saved successfully!'),
                    ),
                  );
                } catch (error) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text('Could not save plan: $error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: Colors.black,
              ),
              child: const Text(
                'Add Plan',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      nameController.dispose();
      durationController.dispose();
      priceController.dispose();
      descriptionController.dispose();
      featuresController.dispose();
    });
  }

  int _calculateValidityDays(int value, String unit) {
    switch (unit) {
      case 'Days':
        return value;
      case 'Weeks':
        return value * 7;
      case 'Months':
        return value * 30;
      case 'Years':
        return value * 365;
      default:
        return value;
    }
  }

  String _formatPrice(String value) {
    final parts = value.split('.');
    final whole = parts[0];
    final buffer = StringBuffer();
    for (int i = 0; i < whole.length; i++) {
      final remaining = whole.length - i;
      buffer.write(whole[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }
    return parts.length > 1 && parts[1] != '00'
        ? '${buffer.toString()}.${parts[1]}'
        : buffer.toString();
  }

  Widget _buildDialogLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: Colors.grey[300],
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  InputDecoration _planInputDecoration(
    String hint, {
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
      prefixIcon: prefixIcon == null
          ? null
          : Icon(prefixIcon, color: Colors.grey[500], size: 18),
      filled: true,
      fillColor: const Color(0xFF292932),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[700]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[700]!),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: Color(0xFF38BDF8), width: 1.3),
      ),
      errorStyle: const TextStyle(color: Colors.redAccent),
    );
  }

  // Show the complete details when an admin taps a membership plan.
  void _showPlanDetails(MembershipPlanItem plan) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                plan.planName,
                style: GoogleFonts.inter(
                  color: const Color(0xFF0F172A),
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: plan.status == 'Active'
                    ? Colors.green.withOpacity(0.10)
                    : Colors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                plan.status,
                style: GoogleFonts.inter(
                  color: plan.status == 'Active'
                      ? Colors.green[700]
                      : Colors.orange[800],
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPlanDetailRow(
                  Icons.schedule_rounded,
                  'Duration',
                  plan.duration,
                ),
                const SizedBox(height: 14),
                _buildPlanDetailRow(
                  Icons.currency_rupee_rounded,
                  'Membership price',
                  plan.price,
                ),
                const SizedBox(height: 20),
                Text(
                  'DESCRIPTION',
                  style: GoogleFonts.inter(
                    color: Colors.grey[500],
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  plan.description.trim().isEmpty
                      ? 'No description added for this plan.'
                      : plan.description,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF334155),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'PLAN FEATURES & BENEFITS',
                  style: GoogleFonts.inter(
                    color: Colors.grey[500],
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 9),
                if (plan.features.isEmpty)
                  Text(
                    'No features added for this plan.',
                    style: GoogleFonts.inter(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  )
                else
                  ...plan.features.map(
                    (feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF16A34A),
                            size: 17,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              feature,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF334155),
                                fontSize: 13,
                                height: 1.4,
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Close',
              style: GoogleFonts.inter(
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: const Color(0xFF2563EB), size: 19),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.grey[500],
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  color: const Color(0xFF0F172A),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Delete Plan Function
  void _deletePlan(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: Text(
          "Delete Plan",
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Text(
          "Are you sure you want to delete this membership plan?",
          style: GoogleFonts.inter(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _supabase
                    .from('membership_plans')
                    .delete()
                    .eq('id', _plans[index].id);

                if (!mounted) return;
                Navigator.pop(context);
                await _loadPlans();

                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text("Membership plan deleted successfully!"),
                  ),
                );
              } catch (error) {
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text("Could not delete plan: $error"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
            ),
            child: const Text(
              "Delete",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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
                  "GYM SETTINGS & PLAN MANAGEMENT",
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[500],
                  ),
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
                                        errorBuilder: (context, error, stackTrace) =>
                                            Container(
                                          width: 52,
                                          height: 52,
                                          decoration: BoxDecoration(
                                            color: primaryColor,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Center(
                                            child: Icon(
                                              Icons.fitness_center_rounded,
                                              color: Color(0xFF38BDF8),
                                              size: 26,
                                            ),
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
                                          style: GoogleFonts.inter(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: primaryColor,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "Official Gym Profile",
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 28),
                                const Divider(
                                  height: 1,
                                  color: Color(0xFFE2E8F0),
                                ),
                                const SizedBox(height: 24),
                                _buildInfoItem("Gym Name", "The Muscle Gym"),
                                const SizedBox(height: 20),
                                _buildInfoItem(
                                  "Address",
                                  "Plot 24, Main Road, Patna, Bihar",
                                ),
                                const SizedBox(height: 20),
                                _buildInfoItem(
                                  "Contact Phone",
                                  "+91 98765 00000",
                                ),
                                const SizedBox(height: 20),
                                _buildInfoItem(
                                  "Support Email",
                                  "hello@themusclegym.in",
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 32),

                      // RIGHT COLUMN: MEMBERSHIP PLANS TABLE
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
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Table Header
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        "Plan name",
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
                                        "Duration",
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
                                        "Price",
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
                                        "Status",
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 40),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Table Rows List with Delete Action
                              Expanded(
                                child: _isLoadingPlans
                                    ? const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    : _plansError != null
                                        ? Center(
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.error_outline,
                                                    color: Colors.redAccent,
                                                    size: 32,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    'Could not load membership plans',
                                                    style: GoogleFonts.inter(
                                                      color: primaryColor,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    _plansError!,
                                                    textAlign: TextAlign.center,
                                                    style: GoogleFonts.inter(
                                                      color: Colors.grey[600],
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                  TextButton.icon(
                                                    onPressed: _loadPlans,
                                                    icon: const Icon(Icons.refresh),
                                                    label: const Text('Try again'),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )
                                        : _plans.isEmpty
                                            ? Center(
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.card_membership_outlined,
                                                      size: 42,
                                                      color: Colors.grey[400],
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Text(
                                                      'No membership plans yet',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w600,
                                                        color: primaryColor,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'Click “Add new plan” to create your first plan.',
                                                      textAlign: TextAlign.center,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 11,
                                                        color: Colors.grey[500],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            : ListView.builder(
                                                itemCount: _plans.length,
                                                itemBuilder: (context, index) {
                                    final plan = _plans[index];
                                    return InkWell(
                                      onTap: () => _showPlanDetails(plan),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
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
                                              plan.planName,
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
                                              plan.duration,
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              plan.price,
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: primaryColor,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Text(
                                              plan.status,
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: plan.status == 'Active'
                                                    ? Colors.green[700]
                                                    : Colors.orange[700],
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () => _deletePlan(index),
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              color: Colors.redAccent,
                                              size: 20,
                                            ),
                                            tooltip: "Delete Plan",
                                          ),
                                        ],
                                      ),
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
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
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[500],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
