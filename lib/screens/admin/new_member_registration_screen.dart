import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'admin_members_view.dart';

class NewMemberRegistrationScreen extends StatefulWidget {
  const NewMemberRegistrationScreen({super.key});

  @override
  State<NewMemberRegistrationScreen> createState() => _NewMemberRegistrationScreenState();
}

class _NewMemberRegistrationScreenState extends State<NewMemberRegistrationScreen> {
  int _currentStep = 1; // 1: Personal details, 2: Plan selection, 3: Payment
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  
  String _selectedPlan = "Gold Plan";
  String _selectedPaymentMethod = "UPI / Cash at Desk";
  File? _profileImage;

  // Function to pick image from device gallery
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
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
            // TOP HEADER
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
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "06 NEW MEMBER REGISTRATION",
                          style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: primaryColor),
                        ),
                        Text(
                          "Manage your gym operations at a glance",
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  "APEX FITNESS",
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: primaryColor, letterSpacing: 1.0),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // MAIN CARD CONTAINER WITH FORM VALIDATION
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5)),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "NEW MEMBER REGISTRATION",
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 20),

                      // STEP INDICATORS BAR
                      Row(
                        children: [
                          _buildStepIndicator(1, "Personal details"),
                          Expanded(child: Container(height: 1, color: Colors.grey[200])),
                          _buildStepIndicator(2, "Plan selection"),
                          Expanded(child: Container(height: 1, color: Colors.grey[200])),
                          _buildStepIndicator(3, "Payment"),
                        ],
                      ),
                      const Divider(height: 32),

                      // STEP CONTENT AREA
                      Expanded(
                        child: SingleChildScrollView(
                          child: _currentStep == 1
                              ? _buildStep1PersonalDetails()
                              : _currentStep == 2
                                  ? _buildStep2PlanSelection()
                                  : _buildStep3Payment(),
                        ),
                      ),

                      // FOOTER BUTTONS
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              if (_currentStep > 1) {
                                setState(() => _currentStep--);
                              } else {
                                Navigator.pop(context);
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(_currentStep == 1 ? "Cancel" : "Back"),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: () {
                              if (_currentStep == 1) {
                                if (!_formKey.currentState!.validate()) {
                                  return;
                                }
                              }
                              if (_currentStep < 3) {
                                setState(() => _currentStep++);
                              } else {
                                // Complete registration and pass new member back to list
                                final createdMember = MemberItem(
                                  name: nameController.text.trim(),
                                  plan: _selectedPlan,
                                  status: "ACTIVE",
                                  daysLeft: 30,
                                  profileImage: _profileImage,
                                );

                                Navigator.pop(context, createdMember);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Member successfully registered!")),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(_currentStep == 3 ? "Complete Registration" : "Continue to plan →"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int stepNumber, String title) {
    bool isActive = _currentStep == stepNumber;
    bool isCompleted = _currentStep > stepNumber;

    return Row(
      children: [
        Text(
          "$stepNumber  ",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: isActive || isCompleted ? const Color(0xFF1E293B) : Colors.grey[400],
          ),
        ),
        Text(
          title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: isActive || isCompleted ? const Color(0xFF1E293B) : Colors.grey[400],
          ),
        ),
      ],
    );
  }

  Widget _buildStep1PersonalDetails() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              _buildRequiredTextField("Full name *", "e.g. Rahul Sharma", nameController),
              const SizedBox(height: 24),
              _buildTextField("Email address", "name@example.com", emailController),
              const SizedBox(height: 24),
              // Member photo upload widget with preview
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Member photo", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _pickImage,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          _profileImage != null
                              ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.file(_profileImage!, width: 32, height: 32, fit: BoxFit.cover))
                              : const Icon(Icons.upload_file, size: 20, color: Colors.grey),
                          const SizedBox(width: 12),
                          Text(
                            _profileImage != null ? "Photo attached successfully" : "Upload photo",
                            style: GoogleFonts.inter(fontSize: 13, color: _profileImage != null ? Colors.green[700] : Colors.grey[500], fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 40),
        Expanded(
          child: Column(
            children: [
              _buildRequiredTextField("Phone number *", "+91 98765 43210", phoneController),
              const SizedBox(height: 24),
              _buildRequiredTextField("Date of birth *", "DD / MM / YYYY", dobController),
              const SizedBox(height: 24),
              _buildTextField("Notes", "Add member notes...", notesController, maxLines: 3),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep2PlanSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Select Membership Plan", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
        const SizedBox(height: 16),
        RadioListTile<String>(
          title: const Text("Gold Plan (₹ 3,500 / month) - Full access + Personal Training"),
          value: "Gold Plan",
          groupValue: _selectedPlan,
          onChanged: (val) => setState(() => _selectedPlan = val!),
        ),
        RadioListTile<String>(
          title: const Text("Silver Plan (₹ 2,200 / month) - Standard Gym Access"),
          value: "Silver Plan",
          groupValue: _selectedPlan,
          onChanged: (val) => setState(() => _selectedPlan = val!),
        ),
        RadioListTile<String>(
          title: const Text("Premium Plan (₹ 5,000 / month) - All Access + Spa & Nutrition"),
          value: "Premium",
          groupValue: _selectedPlan,
          onChanged: (val) => setState(() => _selectedPlan = val!),
        ),
      ],
    );
  }

  Widget _buildStep3Payment() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Choose Payment Method", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
              const SizedBox(height: 16),
              RadioListTile<String>(
                title: const Text("UPI / Cash at Desk"),
                value: "UPI / Cash at Desk",
                groupValue: _selectedPaymentMethod,
                onChanged: (val) => setState(() => _selectedPaymentMethod = val!),
              ),
              RadioListTile<String>(
                title: const Text("Credit / Debit Card"),
                value: "Credit / Debit Card",
                groupValue: _selectedPaymentMethod,
                onChanged: (val) => setState(() => _selectedPaymentMethod = val!),
              ),
            ],
          ),
        ),
        const SizedBox(width: 40),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border.all(color: Colors.grey[200]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text("Scan to Pay", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
              const SizedBox(height: 12),
              Container(
                width: 140,
                height: 140,
                color: Colors.white,
                child: const Center(
                  child: Icon(Icons.qr_code_2, size: 100, color: Color(0xFF1E293B)),
                ),
              ),
              const SizedBox(height: 8),
              Text(_selectedPaymentMethod, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRequiredTextField(String label, String hint, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'This field is required';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey[400]),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, String hint, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey[400]),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}