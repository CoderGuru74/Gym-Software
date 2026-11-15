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

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
                                selectedDate = _expiryForPlan(newlySelectedPlan);
                                expiryController.text = _formatDate(selectedDate);
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
                                  expiryController.text = _formatDate(pickedDate);
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
                          // 1. Extract facial embedding vector via ML Kit + MobileFaceNet
                          final List<double>? embedding =
                              await _faceRecognitionService.extractFaceEmbedding(
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

                          // 2. Upload photo to Supabase Storage bucket
                          final fileName =
                              'member_${DateTime.now().millisecondsSinceEpoch}.jpg';
                          await _supabaseService.client.storage
                              .from('member-photos')
                              .upload(fileName, capturedImage!);

                          final photoUrl = _supabaseService.client.storage
                              .from('member-photos')
                              .getPublicUrl(fileName);

                          // 3. Save member details + public photo URL + face embedding vector
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

    // Defer disposal until after dialog exit transition completes
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
                    "View active gym members, contact info, and plans",
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
                        "View active gym members, contact info, Aadhaar, and plan details",
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
                            constraints: const BoxConstraints(minWidth: 780),
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
                                        width: 140,
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
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ..._members.map((member) {
                                  final hasFaceId = (member['embedding']
                                              ?.toString()
                                              .isNotEmpty ??
                                          false);
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
                                        SizedBox(
                                          width: 140,
                                          child: Text(
                                            member['name'] ?? '',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: primaryColor,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 120,
                                          child: Text(
                                            member['phone'] ?? '',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: Colors.grey[600],
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
                                              color: const Color(0xFF0284C7),
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
                                            padding: const EdgeInsets.symmetric(
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
                                              hasFaceId ? "Active" : "Missing",
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
                                      ],
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