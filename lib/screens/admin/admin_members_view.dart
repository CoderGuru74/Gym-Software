import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/supabase_service.dart';
import '../../services/face_recognition_service.dart';

class AdminMembersView extends StatefulWidget {
  const AdminMembersView({super.key});

  @override
  State<AdminMembersView> createState() => _AdminMembersViewState();
}

class _AdminMembersViewState extends State<AdminMembersView> {
  final _supabaseService = SupabaseService();
  final _faceRecognitionService = FaceRecognitionService();

  List _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _faceRecognitionService.loadModel();
    _fetchMembers();
  }

  @override
  void dispose() {
    _faceRecognitionService.dispose();
    super.dispose();
  }

  Future<void> _fetchMembers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final membersData = await _supabaseService.getMembers();
      if (!mounted) return;
      setState(() {
        _members = membersData is List ? membersData : [];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<List> _fetchAvailablePlans() async {
    final response = await _supabaseService.client
        .from('membership_plans')
        .select('id, plan_name, validity_days, price, status')
        .eq('status', 'Active')
        .order('created_at', ascending: false);

    return (response as List);
  }

  Future<List> _fetchMemberPayments(dynamic member) async {
    final memberName = member['name']?.toString().trim() ?? '';
    if (memberName.isEmpty) return [];

    try {
      final byName = await _supabaseService.client
          .from('payments')
          .select()
          .ilike('member_name', memberName)
          .order('due_date', ascending: false);
      return List.from(byName as List);
    } catch (_) {
      try {
        final byNameUnordered = await _supabaseService.client
            .from('payments')
            .select()
            .ilike('member_name', memberName);
        return List.from(byNameUnordered as List);
      } catch (_) {
        return [];
      }
    }
  }

  Future<List> _fetchMemberAttendance(dynamic member) async {
    final memberId = member['id']?.toString().trim() ?? '';
    final memberName = member['name']?.toString().trim() ?? '';

    if (memberId.isNotEmpty) {
      try {
        final byId = await _supabaseService.client
            .from('attendance')
            .select()
            .eq('member_id', memberId)
            .order('created_at', ascending: false);
        final list = List.from(byId as List);
        if (list.isNotEmpty) return list;
      } catch (_) {}
    }

    if (memberName.isNotEmpty) {
      try {
        final byName = await _supabaseService.client
            .from('attendance')
            .select()
            .ilike('member_name', memberName)
            .order('created_at', ascending: false);
        return List.from(byName as List);
      } catch (_) {
        try {
          final fallback = await _supabaseService.client
              .from('attendance')
              .select()
              .ilike('member_name', memberName);
          return List.from(fallback as List);
        } catch (_) {}
      }
    }

    return [];
  }

  Future<void> _insertPaymentRecord({
    required dynamic member,
    required double amount,
    required String paymentMethod,
    required String planName,
  }) async {
    final memberName = member['name']?.toString().trim() ?? '';
    final effectivePlan =
        planName.trim().isNotEmpty ? planName.trim() : 'General';
    final effectiveDueDate =
        (member['expiry_date']?.toString().trim().isNotEmpty ?? false)
            ? member['expiry_date'].toString().trim()
            : _formatDate(DateTime.now());

    await _supabaseService.client.from('payments').insert({
      'member_name': memberName,
      'plan': effectivePlan,
      'amount': amount,
      'due_date': effectiveDueDate,
    });
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatReadableDate(String raw) {
    if (raw.trim().isEmpty || raw == 'N/A') return 'N/A';
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) return raw.split('T').first;
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
    final local = parsed.toLocal();
    return '${local.day.toString().padLeft(2, '0')} ${months[local.month - 1]} ${local.year}';
  }

  String _formatJoiningDate(dynamic member) {
    final raw = member['joining_date']?.toString() ??
        member['created_at']?.toString() ??
        '';
    if (raw.isEmpty) return 'N/A';
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return _formatDate(parsed.toLocal());
    return raw.split('T').first;
  }

  bool _isMemberActive(String expiryRaw) {
    final parsed = DateTime.tryParse(expiryRaw.trim());
    if (parsed == null) return true;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    return !parsed.isBefore(todayDate);
  }

  String _formatMemberCode(dynamic member) {
    final customCode = member['member_code']?.toString().trim();
    if (customCode != null && customCode.isNotEmpty) return customCode;
    final rawId = member['id']?.toString().trim() ?? '';
    if (rawId.isEmpty) return 'AFX-00000';
    final numeric = int.tryParse(rawId);
    if (numeric != null) {
      return 'AFX-${numeric.toString().padLeft(5, '0')}';
    }
    final shortHex = rawId.replaceAll('-', '').toUpperCase();
    return 'AFX-${shortHex.substring(0, shortHex.length >= 5 ? 5 : shortHex.length)}';
  }

  DateTime _expiryForPlan(dynamic plan) {
    final validityDays =
        int.tryParse(plan['validity_days']?.toString() ?? '') ?? 30;
    return DateTime.now().add(Duration(days: validityDays));
  }

  String _formatPlanPrice(dynamic value) {
    final price = double.tryParse(value?.toString() ?? '') ?? 0;
    final whole = price == price.roundToDouble()
        ? price.toStringAsFixed(0)
        : price.toStringAsFixed(2);
    final parts = whole.split('.');
    final digits = parts.first;
    final buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      buffer.write(digits[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }

    final formattedWhole = buffer.toString();
    return parts.length > 1 && parts[1] != '00'
        ? '₹ $formattedWhole.${parts[1]}'
        : '₹ $formattedWhole';
  }

  String _durationLabel(dynamic validityValue) {
    final days = int.tryParse(validityValue?.toString() ?? '') ?? 30;

    if (days % 365 == 0) {
      final years = days ~/ 365;
      return '$years ${years == 1 ? 'Year' : 'Years'}';
    }
    if (days % 30 == 0) {
      final months = days ~/ 30;
      return '$months ${months == 1 ? 'Month' : 'Months'}';
    }
    if (days % 7 == 0) {
      final weeks = days ~/ 7;
      return '$weeks ${weeks == 1 ? 'Week' : 'Weeks'}';
    }
    return '$days ${days == 1 ? 'Day' : 'Days'}';
  }

  /// Minimalist Professional Member Profile Modal + Attendance History + Inline Edit
  Future<void> _showMemberDetailsDialog(dynamic member) async {
    final rootMessenger = ScaffoldMessenger.of(context);

    List activePlans = [];
    try {
      activePlans = await _fetchAvailablePlans();
    } catch (_) {}

    final nameController =
        TextEditingController(text: member['name']?.toString() ?? '');
    final phoneController =
        TextEditingController(text: member['phone']?.toString() ?? '');
    final emailController =
        TextEditingController(text: member['email']?.toString() ?? '');
    final aadhaarController =
        TextEditingController(text: member['aadhaar']?.toString() ?? '');
    final expiryController =
        TextEditingController(text: member['expiry_date']?.toString() ?? '');
    final notesController = TextEditingController(
      text: (member['trainer_notes'] ?? member['notes'] ?? '').toString(),
    );

    String selectedPlanName = member['plan']?.toString() ?? '';
    final planNames =
        activePlans.map((p) => p['plan_name'].toString()).toList();
    if (selectedPlanName.isNotEmpty && !planNames.contains(selectedPlanName)) {
      planNames.insert(0, selectedPlanName);
    }

    final String existingPhotoUrl = member['photo_path']?.toString() ?? '';
    final String joiningDateStr = _formatJoiningDate(member);
    final String memberCode = _formatMemberCode(member);
    bool hasFaceId = (member['embedding']?.toString().isNotEmpty ?? false);

    File? newCapturedImage;
    bool isSaving = false;
    bool isEditMode = false;
    int selectedTabIndex = 0; // 0: Attendance, 1: Payment Ledger, 2: Notes

    bool isLoadingPayments = true;
    List payments = [];
    bool paymentsFetched = false;

    bool isLoadingAttendance = true;
    List attendanceRecords = [];
    bool attendanceFetched = false;

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (stfContext, setDialogState) {
          if (!paymentsFetched) {
            paymentsFetched = true;
            _fetchMemberPayments(member).then((data) {
              if (dialogContext.mounted) {
                setDialogState(() {
                  payments = data;
                  isLoadingPayments = false;
                });
              }
            });
          }

          if (!attendanceFetched) {
            attendanceFetched = true;
            _fetchMemberAttendance(member).then((data) {
              if (dialogContext.mounted) {
                setDialogState(() {
                  attendanceRecords = data;
                  isLoadingAttendance = false;
                });
              }
            });
          }

          final displayName = nameController.text.trim().isNotEmpty
              ? nameController.text.trim()
              : 'Member';
          final initialLetter = displayName.substring(0, 1).toUpperCase();
          final isActive = _isMemberActive(expiryController.text);
          final isCompact = MediaQuery.of(stfContext).size.width < 760;

          return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            insetPadding: EdgeInsets.symmetric(
              horizontal: isCompact ? 14 : 36,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 920,
                maxHeight: 680,
              ),
              child: Padding(
                padding: EdgeInsets.all(isCompact ? 18 : 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Title Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEditMode ? "EDIT MEMBER PROFILE" : "MEMBER PROFILE",
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        IconButton(
                          onPressed: isSaving
                              ? null
                              : () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF64748B),
                            size: 20,
                          ),
                          tooltip: "Close",
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Profile Header Card (Matches Screenshot)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 16 : 22,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: (!isEditMode || isSaving)
                                ? null
                                : () async {
                                    final picker = ImagePicker();
                                    final XFile? image = await picker.pickImage(
                                      source: ImageSource.camera,
                                      preferredCameraDevice: CameraDevice.front,
                                      maxWidth: 600,
                                      imageQuality: 85,
                                    );
                                    if (image != null && dialogContext.mounted) {
                                      setDialogState(() {
                                        newCapturedImage = File(image.path);
                                      });
                                    }
                                  },
                            child: Stack(
                              children: [
                                Container(
                                  width: 58,
                                  height: 58,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1E293B),
                                    shape: BoxShape.circle,
                                  ),
                                  child: ClipOval(
                                    child: newCapturedImage != null
                                        ? Image.file(
                                            newCapturedImage!,
                                            fit: BoxFit.cover,
                                          )
                                        : existingPhotoUrl.startsWith('http')
                                            ? Image.network(
                                                existingPhotoUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    Center(
                                                  child: Text(
                                                    initialLetter,
                                                    style: GoogleFonts.inter(
                                                      color: Colors.white,
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : Center(
                                                child: Text(
                                                  initialLetter,
                                                  style: GoogleFonts.inter(
                                                    color: Colors.white,
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                  ),
                                ),
                                if (isEditMode)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF0F172A),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt_rounded,
                                        size: 11,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: GoogleFonts.inter(
                                    fontSize: isCompact ? 18 : 21,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  "Member ID  •  $memberCode",
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 3.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? const Color(0xFF16A34A)
                                            : const Color(0xFFDC2626),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        isActive ? "ACTIVE" : "EXPIRED",
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 3.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: (hasFaceId ||
                                                newCapturedImage != null)
                                            ? const Color(0xFFE0F2FE)
                                            : const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        newCapturedImage != null
                                            ? "NEW PHOTO READY"
                                            : hasFaceId
                                                ? "FACE ID ACTIVE"
                                                : "FACE ID MISSING",
                                        style: GoogleFonts.inter(
                                          color: (hasFaceId ||
                                                  newCapturedImage != null)
                                              ? const Color(0xFF0369A1)
                                              : const Color(0xFFB45309),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () {
                                    setDialogState(() {
                                      isEditMode = !isEditMode;
                                    });
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isEditMode
                                  ? const Color(0xFFE2E8F0)
                                  : const Color(0xFF1E293B),
                              foregroundColor: isEditMode
                                  ? const Color(0xFF0F172A)
                                  : Colors.white,
                              elevation: 0,
                              padding: EdgeInsets.symmetric(
                                horizontal: isCompact ? 14 : 22,
                                vertical: 13,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              isEditMode ? "View profile" : "Edit member",
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Body Content: Either Minimalist Two-Column View OR Clean Light Edit Form
                    Flexible(
                      child: SingleChildScrollView(
                        child: isEditMode
                            ? _buildLightEditForm(
                                stfContext: stfContext,
                                dialogContext: dialogContext,
                                setDialogState: setDialogState,
                                member: member,
                                nameController: nameController,
                                phoneController: phoneController,
                                emailController: emailController,
                                aadhaarController: aadhaarController,
                                expiryController: expiryController,
                                planNames: planNames,
                                selectedPlanName: selectedPlanName,
                                activePlans: activePlans,
                                onPlanChanged: (val) {
                                  selectedPlanName = val;
                                },
                                newCapturedImage: newCapturedImage,
                                isSaving: isSaving,
                                onSavingChanged: (val) =>
                                    setDialogState(() => isSaving = val),
                                rootMessenger: rootMessenger,
                              )
                            : _buildMinimalistProfileBody(
                                isCompact: isCompact,
                                phone: phoneController.text.trim(),
                                email: emailController.text.trim(),
                                aadhaar: aadhaarController.text.trim(),
                                plan: selectedPlanName,
                                joiningDate:
                                    _formatReadableDate(joiningDateStr),
                                expiryDate: _formatReadableDate(
                                    expiryController.text.trim()),
                                selectedTabIndex: selectedTabIndex,
                                onTabChanged: (idx) => setDialogState(
                                    () => selectedTabIndex = idx),
                                isLoadingAttendance: isLoadingAttendance,
                                attendanceRecords: attendanceRecords,
                                isLoadingPayments: isLoadingPayments,
                                payments: payments,
                                selectedPlanName: selectedPlanName,
                                notesController: notesController,
                                onRecordPayment: () async {
                                  await _showQuickAddPaymentDialog(
                                    member: member,
                                    defaultPlan: selectedPlanName,
                                    rootMessenger: rootMessenger,
                                  );
                                  final refreshed =
                                      await _fetchMemberPayments(member);
                                  if (dialogContext.mounted) {
                                    setDialogState(() {
                                      payments = refreshed;
                                    });
                                  }
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    Future.delayed(const Duration(milliseconds: 350), () {
      nameController.dispose();
      phoneController.dispose();
      emailController.dispose();
      aadhaarController.dispose();
      expiryController.dispose();
      notesController.dispose();
    });
  }

  Widget _buildMinimalistProfileBody({
    required bool isCompact,
    required String phone,
    required String email,
    required String aadhaar,
    required String plan,
    required String joiningDate,
    required String expiryDate,
    required int selectedTabIndex,
    required ValueChanged<int> onTabChanged,
    required bool isLoadingAttendance,
    required List attendanceRecords,
    required bool isLoadingPayments,
    required List payments,
    required String selectedPlanName,
    required TextEditingController notesController,
    required VoidCallback onRecordPayment,
  }) {
    final leftDetailsColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailBlock(
          label: "CONTACT",
          value: phone.isNotEmpty ? phone : "N/A",
          subValue: email.isNotEmpty ? email : null,
        ),
        const SizedBox(height: 18),
        _buildDetailBlock(
          label: "AADHAAR ID",
          value: aadhaar.isNotEmpty ? aadhaar : "Not provided",
        ),
        const SizedBox(height: 18),
        _buildDetailBlock(
          label: "MEMBERSHIP",
          value: plan.isNotEmpty ? plan : "No active plan",
        ),
        const SizedBox(height: 18),
        _buildDetailBlock(
          label: "JOINED ON",
          value: joiningDate,
        ),
        const SizedBox(height: 18),
        _buildDetailBlock(
          label: "EXPIRY DATE",
          value: expiryDate,
        ),
      ],
    );

    final rightTabsColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Minimalist Horizontal Tabs (Matches Screenshot)
        Row(
          children: [
            _buildProfileTab(
              title: "ATTENDANCE HISTORY",
              isSelected: selectedTabIndex == 0,
              onTap: () => onTabChanged(0),
            ),
            const SizedBox(width: 24),
            _buildProfileTab(
              title: "PAYMENT LEDGER",
              isSelected: selectedTabIndex == 1,
              onTap: () => onTabChanged(1),
            ),
            const SizedBox(width: 24),
            _buildProfileTab(
              title: "TRAINER NOTES",
              isSelected: selectedTabIndex == 2,
              onTap: () => onTabChanged(2),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (selectedTabIndex == 0)
          _buildAttendanceTable(
            isLoading: isLoadingAttendance,
            records: attendanceRecords,
          )
        else if (selectedTabIndex == 1)
          _buildPaymentLedgerTable(
            isLoading: isLoadingPayments,
            payments: payments,
            defaultPlan: selectedPlanName,
            onRecordPayment: onRecordPayment,
          )
        else
          _buildTrainerNotesSection(notesController),
      ],
    );

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          leftDetailsColumn,
          const SizedBox(height: 24),
          rightTabsColumn,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 235,
          child: leftDetailsColumn,
        ),
        const SizedBox(width: 28),
        Expanded(child: rightTabsColumn),
      ],
    );
  }

  Widget _buildDetailBlock({
    required String label,
    required String value,
    String? subValue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1E293B),
          ),
        ),
        if (subValue != null) ...[
          const SizedBox(height: 2),
          Text(
            subValue,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProfileTab({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color:
                    isSelected ? const Color(0xFF0F172A) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: 0.4,
              color: isSelected
                  ? const Color(0xFF0F172A)
                  : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceTable({
    required bool isLoading,
    required List records,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF0F172A),
            strokeWidth: 2,
          ),
        ),
      );
    }

    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0).withOpacity(0.75),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  "Date",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  "Activity",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  "Status",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (records.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 14),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Text(
              "No attendance check-ins recorded yet.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
          )
        else
          ...records.map((rec) {
            final rawTimestamp = (rec['check_in_time'] ??
                    rec['date'] ??
                    rec['created_at'] ??
                    '')
                .toString();
            final formattedDate = _formatReadableDate(rawTimestamp);

            String activityLabel =
                (rec['activity'] ?? rec['session_type'] ?? '').toString().trim();
            if (activityLabel.isEmpty) {
              final parsed = DateTime.tryParse(rawTimestamp)?.toLocal();
              if (parsed != null) {
                activityLabel = parsed.hour < 12
                    ? "Morning workout"
                    : parsed.hour < 17
                        ? "Afternoon session"
                        : "Evening workout";
              } else {
                activityLabel = "Gym workout";
              }
            }

            final statusLabel =
                (rec['status'] ?? 'Checked in').toString().trim();

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      formattedDate,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: const Color(0xFF334155),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      activityLabel,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: const Color(0xFF334155),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      statusLabel,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: const Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildPaymentLedgerTable({
    required bool isLoading,
    required List payments,
    required String defaultPlan,
    required VoidCallback onRecordPayment,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF0F172A),
            strokeWidth: 2,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onRecordPayment,
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              size: 15,
              color: Color(0xFF0F172A),
            ),
            label: Text(
              "Record Payment",
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0).withOpacity(0.75),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  "Due / Paid Date",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  "Plan / Mode",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  "Amount",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (payments.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 14),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Text(
              "No payment records found for this member.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
          )
        else
          ...payments.map((pay) {
            final amount =
                _formatPlanPrice(pay['amount'] ?? pay['price'] ?? 0);
            final rawDate = (pay['due_date'] ??
                    pay['payment_date'] ??
                    pay['date'] ??
                    pay['created_at'] ??
                    '')
                .toString();
            final payDate = _formatReadableDate(rawDate);
            final method = (pay['payment_method'] ??
                    pay['mode'] ??
                    pay['method'] ??
                    'Paid')
                .toString();
            final planLabel =
                (pay['plan'] ?? pay['plan_name'] ?? defaultPlan).toString();

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      payDate,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: const Color(0xFF334155),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      "$planLabel ($method)",
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: const Color(0xFF334155),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      amount,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildTrainerNotesSection(TextEditingController notesController) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Trainer & Fitness Notes",
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: notesController,
            maxLines: 4,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF334155),
            ),
            decoration: InputDecoration(
              hintText:
                  "Add workout goals, injury notes, or trainer observations...",
              hintStyle: GoogleFonts.inter(
                fontSize: 12.5,
                color: const Color(0xFF94A3B8),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLightEditForm({
    required BuildContext stfContext,
    required BuildContext dialogContext,
    required StateSetter setDialogState,
    required dynamic member,
    required TextEditingController nameController,
    required TextEditingController phoneController,
    required TextEditingController emailController,
    required TextEditingController aadhaarController,
    required TextEditingController expiryController,
    required List<String> planNames,
    required String selectedPlanName,
    required List activePlans,
    required ValueChanged<String> onPlanChanged,
    required File? newCapturedImage,
    required bool isSaving,
    required ValueChanged<bool> onSavingChanged,
    required ScaffoldMessengerState rootMessenger,
  }) {
    InputDecoration lightInput(String label) {
      return InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          color: const Color(0xFF64748B),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Tap the avatar above to capture a new live photo for Face ID recognition.",
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: nameController,
                style: GoogleFonts.inter(color: const Color(0xFF0F172A)),
                decoration: lightInput("Full Name"),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.inter(color: const Color(0xFF0F172A)),
                decoration: lightInput("Phone Number"),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.inter(color: const Color(0xFF0F172A)),
                decoration: lightInput("Email Address"),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextField(
                controller: aadhaarController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(color: const Color(0xFF0F172A)),
                decoration: lightInput("Aadhaar Number"),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            if (planNames.isNotEmpty)
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: planNames.contains(selectedPlanName)
                      ? selectedPlanName
                      : planNames.first,
                  dropdownColor: Colors.white,
                  style: GoogleFonts.inter(color: const Color(0xFF0F172A)),
                  decoration: lightInput("Membership Plan"),
                  items: planNames
                      .map(
                        (plan) => DropdownMenuItem<String>(
                          value: plan,
                          child: Text(plan),
                        ),
                      )
                      .toList(),
                  onChanged: isSaving
                      ? null
                      : (val) {
                          if (val != null) {
                            setDialogState(() {
                              onPlanChanged(val);
                              for (var p in activePlans) {
                                if (p['plan_name'].toString() == val) {
                                  expiryController.text =
                                      _formatDate(_expiryForPlan(p));
                                  break;
                                }
                              }
                            });
                          }
                        },
                ),
              ),
            if (planNames.isNotEmpty) const SizedBox(width: 14),
            Expanded(
              child: TextField(
                controller: expiryController,
                readOnly: true,
                style: GoogleFonts.inter(color: const Color(0xFF0F172A)),
                decoration: lightInput("Expiry Date").copyWith(
                  suffixIcon: const Icon(
                    Icons.calendar_month_rounded,
                    color: Color(0xFF0F172A),
                  ),
                ),
                onTap: isSaving
                    ? null
                    : () async {
                        final initial =
                            DateTime.tryParse(expiryController.text) ??
                                DateTime.now();
                        final picked = await showDatePicker(
                          context: stfContext,
                          initialDate: initial,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null && dialogContext.mounted) {
                          setDialogState(() {
                            expiryController.text = _formatDate(picked);
                          });
                        }
                      },
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            TextButton.icon(
              onPressed: isSaving
                  ? null
                  : () async {
                      final confirm = await showDialog<bool>(
                        context: stfContext,
                        builder: (c) => AlertDialog(
                          backgroundColor: Colors.white,
                          title: const Text(
                            "Delete Member?",
                            style: TextStyle(color: Color(0xFF0F172A)),
                          ),
                          content: Text(
                            "Remove ${member['name']} permanently from the database?",
                            style: const TextStyle(color: Color(0xFF475569)),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text("Cancel"),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(c, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text("Delete"),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        onSavingChanged(true);
                        try {
                          await _supabaseService.client
                              .from('members')
                              .delete()
                              .eq('id', member['id']);
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                          if (mounted) {
                            await _fetchMembers();
                            rootMessenger.showSnackBar(
                              const SnackBar(
                                content: Text("Member deleted."),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        } catch (e) {
                          if (dialogContext.mounted) {
                            onSavingChanged(false);
                          }
                          rootMessenger.showSnackBar(
                            SnackBar(
                              content: Text("Delete error: $e"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFDC2626),
                size: 18,
              ),
              label: Text(
                "Delete Member",
                style: GoogleFonts.inter(
                  color: const Color(0xFFDC2626),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final updatedName = nameController.text.trim();
                      final updatedPhone = phoneController.text.trim();

                      if (updatedName.isEmpty || updatedPhone.isEmpty) {
                        rootMessenger.showSnackBar(
                          const SnackBar(
                            content:
                                Text("Name and Phone number are required."),
                          ),
                        );
                        return;
                      }

                      onSavingChanged(true);

                      try {
                        final Map<String, dynamic> updatePayload = {
                          'name': updatedName,
                          'phone': updatedPhone,
                          'email': emailController.text.trim(),
                          'aadhaar': aadhaarController.text.trim(),
                          'plan': selectedPlanName,
                          'expiry_date': expiryController.text.trim(),
                        };

                        if (newCapturedImage != null) {
                          final embedding = await _faceRecognitionService
                              .extractFaceEmbedding(newCapturedImage);
                          if (embedding == null) {
                            if (dialogContext.mounted) {
                              onSavingChanged(false);
                            }
                            rootMessenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "No clear face detected in new photo. Please retake.",
                                ),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            return;
                          }

                          final fileName =
                              'member_${DateTime.now().millisecondsSinceEpoch}.jpg';
                          await _supabaseService.client.storage
                              .from('member-photos')
                              .upload(fileName, newCapturedImage);

                          final newPhotoUrl = _supabaseService.client.storage
                              .from('member-photos')
                              .getPublicUrl(fileName);

                          updatePayload['photo_path'] = newPhotoUrl;
                          updatePayload['embedding'] = embedding.join(',');
                        }

                        await _supabaseService.client
                            .from('members')
                            .update(updatePayload)
                            .eq('id', member['id']);

                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }

                        if (mounted) {
                          await _fetchMembers();
                          rootMessenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Member details updated in database!",
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (dialogContext.mounted) {
                          onSavingChanged(false);
                        }
                        rootMessenger.showSnackBar(
                          SnackBar(
                            content: Text("Error updating member: $e"),
                            backgroundColor: Colors.red[700],
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      "Save Changes",
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showQuickAddPaymentDialog({
    required dynamic member,
    required String defaultPlan,
    required ScaffoldMessengerState rootMessenger,
  }) async {
    final amountController = TextEditingController();
    String paymentMethod = 'UPI';
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (payDialogContext) => StatefulBuilder(
        builder: (context, setPayState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(
            "Record Payment for ${member['name']}",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration("Amount (₹)"),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: paymentMethod,
                dropdownColor: const Color(0xFF2A2A32),
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration("Payment Mode"),
                items: ['UPI', 'Cash', 'Card', 'Bank Transfer']
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setPayState(() => paymentMethod = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () => Navigator.of(payDialogContext).pop(),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final amt = double.tryParse(amountController.text.trim());
                      if (amt == null || amt <= 0) {
                        rootMessenger.showSnackBar(
                          const SnackBar(
                            content: Text("Enter a valid payment amount."),
                          ),
                        );
                        return;
                      }
                      setPayState(() => isSubmitting = true);
                      try {
                        await _insertPaymentRecord(
                          member: member,
                          amount: amt,
                          paymentMethod: paymentMethod,
                          planName: defaultPlan,
                        );
                        if (payDialogContext.mounted) {
                          Navigator.of(payDialogContext).pop();
                        }
                        rootMessenger.showSnackBar(
                          const SnackBar(
                            content: Text("Payment recorded!"),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        setPayState(() => isSubmitting = false);
                        rootMessenger.showSnackBar(
                          SnackBar(
                            content: Text("Could not save payment: $e"),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
              ),
              child: const Text(
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
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      amountController.dispose();
    });
  }

  Future<void> _showAddMemberDialog() async {
    final rootMessenger = ScaffoldMessenger.of(context);
    List activePlans = [];

    try {
      activePlans = await _fetchAvailablePlans();
    } catch (error) {
      if (!mounted) return;
      rootMessenger.showSnackBar(
        SnackBar(
          content: Text('Could not load membership plans: $error'),
          backgroundColor: Colors.red[700],
        ),
      );
      return;
    }

    if (!mounted) return;

    if (activePlans.isEmpty) {
      rootMessenger.showSnackBar(
        const SnackBar(
          content: Text(
            'No active membership plans found. Add or activate a plan in Gym Settings first.',
          ),
        ),
      );
      return;
    }

    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final aadhaarController = TextEditingController();
    File? capturedImage;
    bool isSaving = false;

    String selectedPlanName = activePlans.first['plan_name'].toString();
    DateTime selectedDate = _expiryForPlan(activePlans.first);
    final expiryController = TextEditingController(
      text: _formatDate(selectedDate),
    );

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (stfContext, setDialogState) {
          dynamic selectedPlan = activePlans.first;
          for (var p in activePlans) {
            if (p['plan_name'].toString() == selectedPlanName) {
              selectedPlan = p;
              break;
            }
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              "Register New Member",
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: isSaving
                            ? null
                            : () async {
                                final ImagePicker picker = ImagePicker();
                                final XFile? image = await picker.pickImage(
                                  source: ImageSource.camera,
                                  preferredCameraDevice: CameraDevice.front,
                                  maxWidth: 600,
                                  imageQuality: 85,
                                );
                                if (image != null && dialogContext.mounted) {
                                  setDialogState(() {
                                    capturedImage = File(image.path);
                                  });
                                }
                              },
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A32),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF38BDF8),
                              width: 2,
                            ),
                            image: capturedImage != null
                                ? DecorationImage(
                                    image: FileImage(capturedImage!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: capturedImage == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.camera_alt_rounded,
                                      color: Color(0xFF38BDF8),
                                      size: 28,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Live Photo",
                                      style: GoogleFonts.inter(
                                        color: Colors.grey[400],
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        capturedImage == null
                            ? "Required for Face Kiosk Recognition"
                            : "Tap photo to retake",
                        style: GoogleFonts.inter(
                          color: capturedImage == null
                              ? const Color(0xFF38BDF8)
                              : Colors.grey[400],
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration("Full Name"),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration("Phone Number"),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration("Email Address"),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: aadhaarController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration("Aadhaar Number (12 Digits)"),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: selectedPlanName,
                      dropdownColor: const Color(0xFF2A2A32),
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration("Membership Plan"),
                      items: activePlans.map<DropdownMenuItem<String>>((plan) {
                        final planName = plan['plan_name'].toString();
                        final duration = _durationLabel(plan['validity_days']);
                        final price = _formatPlanPrice(plan['price']);

                        return DropdownMenuItem<String>(
                          value: planName,
                          child: Text(
                            '$planName - $duration - $price',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: isSaving
                          ? null
                          : (value) {
                              if (value == null) return;

                              dynamic newlySelectedPlan = activePlans.first;
                              for (var p in activePlans) {
                                if (p['plan_name'].toString() ==
                                    value.toString()) {
                                  newlySelectedPlan = p;
                                  break;
                                }
                              }

                              setDialogState(() {
                                selectedPlanName = value;
                                selectedDate =
                                    _expiryForPlan(newlySelectedPlan);
                                expiryController.text =
                                    _formatDate(selectedDate);
                              });
                            },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A32),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF38BDF8).withOpacity(0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedPlan['plan_name'].toString(),
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Validity: ${_durationLabel(selectedPlan['validity_days'])}',
                                style: GoogleFonts.inter(
                                  color: Colors.grey[300],
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                _formatPlanPrice(selectedPlan['price']),
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF38BDF8),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: expiryController,
                      readOnly: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration("Expiry Date").copyWith(
                        suffixIcon: const Icon(
                          Icons.calendar_month_rounded,
                          color: Color(0xFF38BDF8),
                        ),
                      ),
                      onTap: isSaving
                          ? null
                          : () async {
                              final pickedDate = await showDatePicker(
                                context: stfContext,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );

                              if (pickedDate != null && dialogContext.mounted) {
                                setDialogState(() {
                                  selectedDate = pickedDate;
                                  expiryController.text =
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
                onPressed: isSaving
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        final phone = phoneController.text.trim();

                        if (name.isEmpty || phone.isEmpty) {
                          rootMessenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please enter the member name and phone number.',
                              ),
                            ),
                          );
                          return;
                        }

                        if (capturedImage == null) {
                          rootMessenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please capture a live photo so the face kiosk can recognize this member.',
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        setDialogState(() => isSaving = true);

                        try {
                          final List<double>? embedding =
                              await _faceRecognitionService
                                  .extractFaceEmbedding(
                            capturedImage!,
                          );

                          if (embedding == null) {
                            if (dialogContext.mounted) {
                              setDialogState(() => isSaving = false);
                            }
                            rootMessenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No clear face detected in the photo. Please retake in good lighting.',
                                ),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            return;
                          }

                          final fileName =
                              'member_${DateTime.now().millisecondsSinceEpoch}.jpg';
                          await _supabaseService.client.storage
                              .from('member-photos')
                              .upload(fileName, capturedImage!);

                          final photoUrl = _supabaseService.client.storage
                              .from('member-photos')
                              .getPublicUrl(fileName);

                          await _supabaseService.client.from('members').insert({
                            'name': name,
                            'phone': phone,
                            'email': emailController.text.trim(),
                            'aadhaar': aadhaarController.text.trim(),
                            'plan': selectedPlanName,
                            'expiry_date': expiryController.text.trim(),
                            'photo_path': photoUrl,
                            'embedding': embedding.join(','),
                          });

                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }

                          if (mounted) {
                            await _fetchMembers();
                            rootMessenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Member and face profile registered successfully!",
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (error) {
                          if (dialogContext.mounted) {
                            setDialogState(() => isSaving = false);
                          }
                          rootMessenger.showSnackBar(
                            SnackBar(
                              content: Text("Error registering member: $error"),
                              backgroundColor: Colors.red[700],
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
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "Register Member",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );

    Future.delayed(const Duration(milliseconds: 350), () {
      nameController.dispose();
      phoneController.dispose();
      emailController.dispose();
      aadhaarController.dispose();
      expiryController.dispose();
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
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (isMobile) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "MEMBERS MANAGEMENT",
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Tap any member row to view full profile, attendance, payments & edit",
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _fetchMembers,
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: primaryColor,
                        ),
                        tooltip: "Refresh Members",
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _showAddMemberDialog,
                        icon: const Icon(Icons.person_add_rounded, size: 16),
                        label: const Text("Add Member"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            } else {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "MEMBERS MANAGEMENT",
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: primaryColor,
                        ),
                      ),
                      Text(
                        "Tap any member row to view full profile, attendance history, payment ledger, and edit details",
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
                        onPressed: _fetchMembers,
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: primaryColor,
                        ),
                        tooltip: "Refresh Members",
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _showAddMemberDialog,
                        icon: const Icon(Icons.person_add_rounded, size: 16),
                        label: const Text("Add New Member"),
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
              );
            }
          },
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
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
                    child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
                  )
                : _members.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.group_off_rounded,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "No gym members registered yet.",
                              style: GoogleFonts.inter(
                                color: Colors.grey[600],
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 820),
                            child: Column(
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
                                      SizedBox(
                                        width: 150,
                                        child: Text(
                                          "Name",
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 120,
                                        child: Text(
                                          "Phone",
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 130,
                                        child: Text(
                                          "Aadhaar",
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 120,
                                        child: Text(
                                          "Plan",
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 110,
                                        child: Text(
                                          "Expiry Date",
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 90,
                                        child: Text(
                                          "Face ID",
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
                                ..._members.map((member) {
                                  final hasFaceId = (member['embedding']
                                              ?.toString()
                                              .isNotEmpty ??
                                          false);
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () =>
                                        _showMemberDetailsDialog(member),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                      margin: const EdgeInsets.only(bottom: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.grey[200]!,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 150,
                                            child: Text(
                                              member['name'] ?? '',
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF0284C7),
                                                decoration:
                                                    TextDecoration.underline,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 120,
                                            child: Text(
                                              member['phone'] ?? '',
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 130,
                                            child: Text(
                                              member['aadhaar'] ?? 'N/A',
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 120,
                                            child: Text(
                                              member['plan'] ?? '',
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: primaryColor,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 110,
                                            child: Text(
                                              member['expiry_date'] ?? '',
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 90,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: hasFaceId
                                                    ? const Color(0xFF10B981)
                                                        .withOpacity(0.12)
                                                    : Colors.orange
                                                        .withOpacity(0.12),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                hasFaceId
                                                    ? "Active"
                                                    : "Missing",
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: hasFaceId
                                                      ? const Color(0xFF059669)
                                                      : Colors.orange[800],
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                            width: 40,
                                            child: Icon(
                                              Icons.edit_note_rounded,
                                              color: Color(0xFF38BDF8),
                                              size: 20,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
          ),
        ),
      ],
    );
  }
}