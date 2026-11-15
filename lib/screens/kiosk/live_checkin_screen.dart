import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:camera/camera.dart';
import '../../services/supabase_service.dart';
import '../../services/face_recognition_service.dart';
import '../admin/admin_dashboard_screen.dart';

class LiveCheckinScreen extends StatefulWidget {
  const LiveCheckinScreen({super.key});

  @override
  State<LiveCheckinScreen> createState() => _LiveCheckinScreenState();
}

class _LiveCheckinScreenState extends State<LiveCheckinScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final FaceRecognitionService _faceRecognitionService = FaceRecognitionService();

  late String _timeString;
  late String _dateString;
  late Timer _timer;

  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isVerifying = false;
  String? _cameraError;

  List<dynamic> _recentCheckins = [];
  bool _isLoadingFeed = true;

  @override
  void initState() {
    super.initState();
    _timeString = DateFormat('hh:mm:ss a').format(DateTime.now());
    _dateString = DateFormat('EEEE • dd MMMM yyyy').format(DateTime.now()).toUpperCase();

    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _updateTime());

    _faceRecognitionService.loadModel();
    _initMobileCamera();
    _fetchRecentCheckins();
  }

  @override
  void dispose() {
    _timer.cancel();
    _cameraController?.dispose();
    _faceRecognitionService.dispose();
    super.dispose();
  }

  void _updateTime() {
    if (mounted) {
      setState(() {
        _timeString = DateFormat('hh:mm:ss a').format(DateTime.now());
        _dateString = DateFormat('EEEE • dd MMMM yyyy').format(DateTime.now()).toUpperCase();
      });
    }
  }

  Future<void> _initMobileCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        final frontCamera = cameras.firstWhere(
          (cam) => cam.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );

        _cameraController = CameraController(
          frontCamera,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
            _cameraError = null;
          });
        }
      } else {
        if (mounted) {
          setState(() => _cameraError = "No camera found on device.");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cameraError = "Camera init error: $e");
      }
    }
  }

  Future<void> _fetchRecentCheckins() async {
    if (!mounted) return;
    setState(() => _isLoadingFeed = true);
    try {
      final logs = await _supabaseService.getAttendanceLogs();
      if (mounted) {
        setState(() {
          _recentCheckins = logs;
          _isLoadingFeed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingFeed = false);
    }
  }

  // Real On-Device Face Recognition via MobileFaceNet + Cosine Similarity
  Future<void> _verifyFaceAndCheckIn() async {
    if (_isVerifying) return;
    if (!_isCameraInitialized || _cameraController == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Camera not ready. Please wait."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isVerifying = true);

    try {
      // 1. Capture live camera frame
      final XFile capturedImage = await _cameraController!.takePicture();
      final File imageFile = File(capturedImage.path);

      // 2. Detect, crop, and extract facial embedding vector
      final List<double>? liveEmbedding =
          await _faceRecognitionService.extractFaceEmbedding(imageFile);

      // Clean up temporary capture file
      if (await imageFile.exists()) {
        await imageFile.delete();
      }

      if (liveEmbedding == null) {
        if (mounted) {
          setState(() => _isVerifying = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("No face detected! Please look directly at the camera."),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      // 3. Fetch registered members from Supabase
      final members = await _supabaseService.getMembers();

      if (members.isEmpty) {
        if (mounted) {
          setState(() => _isVerifying = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("No registered members found in database!"),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 4. Compare live embedding against every member's stored embedding
      dynamic bestMatchMember;
      double highestSimilarity = -1.0;

      for (var member in members) {
        final embStr = member['embedding']?.toString() ?? '';
        if (embStr.isEmpty) continue;

        final storedEmbedding = embStr
            .split(',')
            .map((val) => double.tryParse(val.trim()) ?? 0.0)
            .toList();

        if (storedEmbedding.length != liveEmbedding.length) continue;

        final double similarity = _faceRecognitionService.cosineSimilarity(
          liveEmbedding,
          storedEmbedding,
        );

        if (similarity > highestSimilarity) {
          highestSimilarity = similarity;
          bestMatchMember = member;
        }
      }

      // 5. Threshold check (0.72 is balanced for front-camera lighting differences)
      const double matchThreshold = 0.72;

      if (bestMatchMember == null || highestSimilarity < matchThreshold) {
        if (mounted) {
          setState(() => _isVerifying = false);
          showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Face Not Recognized",
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              content: Text(
                "No matching face profile found (Best Match Score: ${(highestSimilarity < 0 ? 0 : highestSimilarity * 100).toStringAsFixed(1)}%). Please register with a live photo first or try again in better lighting.",
                style: GoogleFonts.inter(color: Colors.grey[300], fontSize: 13),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8)),
                  child: const Text(
                    "OK",
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        }
        return;
      }

      final memberId = bestMatchMember['id'];
      final memberName = bestMatchMember['name'] ?? 'Gym Member';
      final memberPlan = bestMatchMember['plan'] ?? 'Active Plan';
      final confidencePercent = (highestSimilarity * 100).toStringAsFixed(1);

      // 6. Log attendance for the exact matched member in Supabase
      await _supabaseService.client.from('attendance').insert({
        'member_id': memberId,
        'member_name': memberName,
        'time_in': DateFormat('hh:mm a').format(DateTime.now()),
        'status': 'FACE VERIFIED',
        'date': DateTime.now().toIso8601String().split('T')[0],
      });

      await _fetchRecentCheckins();

      if (mounted) {
        setState(() => _isVerifying = false);
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Face Recognized!",
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Member: $memberName",
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Plan: $memberPlan",
                  style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  "Match Confidence: $confidencePercent%",
                  style: GoogleFonts.inter(color: const Color(0xFF38BDF8), fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  "Status: Attendance Logged",
                  style: GoogleFonts.inter(
                    color: const Color(0xFF10B981),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8)),
                child: const Text(
                  "Done",
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVerifying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Verification error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openStaffLogin() {
    final TextEditingController pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Staff Dashboard Login",
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Enter administrator password to access the full gym management dashboard.",
                style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Admin Password (try 'admin' or '1234')",
                  labelStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF2A2A32),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (pinController.text.trim() == "1234" ||
                  pinController.text.trim() == "admin") {
                Navigator.pop(dialogContext);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminDashboardScreen(),
                  ),
                );
              } else {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text("Incorrect password!"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8)),
            child: const Text(
              "Login",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const darkPanelColor = Color(0xFF0F172A);
    const lightBgColor = Color(0xFFF1F5F9);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    return Scaffold(
      backgroundColor: lightBgColor,
      body: SafeArea(
        child: isMobile
            ? SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      color: darkPanelColor,
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.fitness_center_rounded,
                                color: Color(0xFF38BDF8),
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "THE MUSCLES GYM",
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  Text(
                                    "STRONGER THAN YESTERDAY",
                                    style: GoogleFonts.inter(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.amber[700],
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            height: 220,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF38BDF8),
                                width: 2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: _isCameraInitialized && _cameraController != null
                                  ? CameraPreview(_cameraController!)
                                  : Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Text(
                                          _cameraError ?? "Initializing Mobile Camera...",
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.inter(
                                            color: Colors.grey[400],
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _isVerifying ? null : _verifyFaceAndCheckIn,
                            icon: _isVerifying
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      color: Colors.black,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.face_retouching_natural_rounded,
                                    color: Colors.black,
                                  ),
                            label: Text(
                              _isVerifying ? "Recognizing Face..." : "Start Face Check-In",
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF38BDF8),
                              minimumSize: const Size(double.infinity, 46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _openStaffLogin,
                            icon: const Icon(
                              Icons.lock_outline_rounded,
                              color: Colors.white70,
                              size: 16,
                            ),
                            label: const Text(
                              "Staff Dashboard Login",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.white.withOpacity(0.2)),
                              minimumSize: const Size(double.infinity, 42),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "LIVE CHECK-INS FEED",
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: darkPanelColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _isLoadingFeed
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF38BDF8),
                                  ),
                                )
                              : _recentCheckins.isEmpty
                                  ? Text(
                                      "No face check-ins recorded yet today.",
                                      style: GoogleFonts.inter(color: Colors.grey[500]),
                                    )
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: _recentCheckins.length,
                                      itemBuilder: (context, index) {
                                        final checkin = _recentCheckins[index];
                                        final memberName =
                                            checkin['member_name'] ?? 'Gym Member';
                                        return _buildCheckinCard(
                                          memberName,
                                          "Member • Face Verified • ${checkin['time_in'] ?? 'Just now'}",
                                          memberName.isNotEmpty
                                              ? memberName[0].toUpperCase()
                                              : 'M',
                                          Colors.blueGrey,
                                        );
                                      },
                                    ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : Row(
                children: [
                  SizedBox(
                    width: screenWidth * 0.40,
                    child: Container(
                      color: darkPanelColor,
                      padding: const EdgeInsets.all(24.0),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.fitness_center_rounded,
                                  color: Color(0xFF38BDF8),
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "THE MUSCLES GYM",
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.5,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      "STRONGER THAN YESTERDAY",
                                      style: GoogleFonts.inter(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.2,
                                        color: Colors.amber[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Container(
                              height: 190,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF38BDF8),
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: _isCameraInitialized && _cameraController != null
                                    ? CameraPreview(_cameraController!)
                                    : Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Text(
                                            _cameraError ?? "Initializing Camera...",
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.inter(
                                              color: Colors.grey[400],
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              onPressed: _isVerifying ? null : _verifyFaceAndCheckIn,
                              icon: _isVerifying
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.black,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.face_retouching_natural_rounded,
                                      color: Colors.black,
                                    ),
                              label: Text(
                                _isVerifying
                                    ? "Recognizing Face..."
                                    : "Start Face Check-In",
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF38BDF8),
                                minimumSize: const Size(double.infinity, 44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: _openStaffLogin,
                              icon: const Icon(
                                Icons.lock_outline_rounded,
                                color: Colors.white70,
                                size: 16,
                              ),
                              label: const Text(
                                "Staff Dashboard Login",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.white.withOpacity(0.2)),
                                minimumSize: const Size(double.infinity, 40),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _timeString,
                              style: GoogleFonts.inter(
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _dateString,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40.0,
                        vertical: 32.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "LIVE CHECK-INS FEED",
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: darkPanelColor,
                                ),
                              ),
                              IconButton(
                                onPressed: _fetchRecentCheckins,
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  color: darkPanelColor,
                                ),
                                tooltip: "Refresh Feed",
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Expanded(
                            child: _isLoadingFeed
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF38BDF8),
                                    ),
                                  )
                                : _recentCheckins.isEmpty
                                    ? Center(
                                        child: Text(
                                          "No face check-ins recorded yet today.",
                                          style: GoogleFonts.inter(
                                            color: Colors.grey[500],
                                            fontSize: 14,
                                          ),
                                        ),
                                      )
                                    : ListView.builder(
                                        itemCount: _recentCheckins.length,
                                        itemBuilder: (context, index) {
                                          final checkin = _recentCheckins[index];
                                          final memberName =
                                              checkin['member_name'] ?? 'Gym Member';
                                          return _buildCheckinCard(
                                            memberName,
                                            "Member • Face Verified • ${checkin['time_in'] ?? 'Just now'}",
                                            memberName.isNotEmpty
                                                ? memberName[0].toUpperCase()
                                                : 'M',
                                            Colors.blueGrey,
                                          );
                                        },
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

  Widget _buildCheckinCard(
    String name,
    String subtitle,
    String initial,
    Color avatarColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: avatarColor,
            child: Text(
              initial,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "FACE VERIFIED",
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}