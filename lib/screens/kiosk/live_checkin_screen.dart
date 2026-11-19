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

  static const Color _crimsonPrimary = Color(0xFFEF233C);
  static const Color _crimsonDeep = Color(0xFFB91C1C);
  static const Color _bgObsidian = Color(0xFF0A0B0E);
  static const Color _cardSurface = Color(0xFF14161D);

  @override
  void initState() {
    super.initState();
    _timeString = DateFormat('hh:mm:ss a').format(DateTime.now());
    _dateString = DateFormat('EEEE • dd MMM yyyy').format(DateTime.now()).toUpperCase();

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
        _dateString = DateFormat('EEEE • dd MMM yyyy').format(DateTime.now()).toUpperCase();
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
      final XFile capturedImage = await _cameraController!.takePicture();
      final File imageFile = File(capturedImage.path);

      final List<double>? liveEmbeddingNormal =
          await _faceRecognitionService.extractFaceEmbedding(imageFile, flipHorizontal: false);
      final List<double>? liveEmbeddingFlipped =
          await _faceRecognitionService.extractFaceEmbedding(imageFile, flipHorizontal: true);

      if (await imageFile.exists()) {
        await imageFile.delete();
      }

      if (liveEmbeddingNormal == null) {
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

      dynamic bestMatchMember;
      double highestSimilarity = -1.0;

      for (var member in members) {
        final embStr = member['embedding']?.toString() ?? '';
        if (embStr.isEmpty) continue;

        final storedEmbedding = embStr
            .split(',')
            .map((val) => double.tryParse(val.trim()) ?? 0.0)
            .toList();

        if (storedEmbedding.length != liveEmbeddingNormal.length) continue;

        final double simNormal = _faceRecognitionService.cosineSimilarity(
          liveEmbeddingNormal,
          storedEmbedding,
        );
        final double simFlipped = liveEmbeddingFlipped != null
            ? _faceRecognitionService.cosineSimilarity(
                liveEmbeddingFlipped,
                storedEmbedding,
              )
            : -1.0;

        final double similarity = simNormal > simFlipped ? simNormal : simFlipped;

        if (similarity > highestSimilarity) {
          highestSimilarity = similarity;
          bestMatchMember = member;
        }
      }

      const double matchThreshold = 0.58;

      if (bestMatchMember == null || highestSimilarity < matchThreshold) {
        if (mounted) {
          setState(() => _isVerifying = false);
          showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              backgroundColor: const Color(0xFF16181F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              title: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: _crimsonPrimary, size: 28),
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
                  style: ElevatedButton.styleFrom(backgroundColor: _crimsonPrimary),
                  child: const Text(
                    "OK",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
            backgroundColor: const Color(0xFF16181F),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: const Color(0xFF10B981).withOpacity(0.35)),
            ),
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
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                child: const Text(
                  "Done",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
        backgroundColor: const Color(0xFF16181F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        title: Row(
          children: [
            _buildBrandLogo(size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Staff Dashboard Login",
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
          ],
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
                  fillColor: const Color(0xFF232631),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
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
            style: ElevatedButton.styleFrom(backgroundColor: _crimsonPrimary),
            child: const Text(
              "Login",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandLogo({double size = 40}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _crimsonPrimary, width: 1.8),
        boxShadow: [
          BoxShadow(
            color: _crimsonPrimary.withOpacity(0.35),
            blurRadius: 10,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/muscle.jpeg',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFF1E2029),
            child: Icon(
              Icons.fitness_center_rounded,
              color: _crimsonPrimary,
              size: size * 0.55,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 800;

    return Scaffold(
      backgroundColor: _bgObsidian,
      body: SizedBox(
        width: screenSize.width,
        height: screenSize.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Full-Screen Gym Background Image
            Positioned.fill(
              child: Image.asset(
                'assets/images/gym_bg.jpg',
                width: screenSize.width,
                height: screenSize.height,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (_, __, ___) => Container(color: _bgObsidian),
              ),
            ),

            // 2. Balanced Translucent Dark Overlay so gym_bg.jpg stays clearly visible
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _bgObsidian.withOpacity(0.55),
                      _bgObsidian.withOpacity(0.68),
                      _bgObsidian.withOpacity(0.84),
                      _bgObsidian.withOpacity(0.92),
                    ],
                    stops: const [0.0, 0.35, 0.70, 1.0],
                  ),
                ),
              ),
            ),

            // 3. Foreground Scrollable / Split Content
            SafeArea(
              child: isMobile
                  ? SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: screenSize.height -
                              MediaQuery.of(context).padding.top -
                              MediaQuery.of(context).padding.bottom -
                              32,
                        ),
                        child: Column(
                          children: [
                            _buildBrandHeader(),
                            const SizedBox(height: 22),
                            _buildCameraViewport(height: 245),
                            const SizedBox(height: 20),
                            _buildPrimaryCheckInButton(),
                            const SizedBox(height: 12),
                            _buildStaffLoginButton(),
                            const SizedBox(height: 24),
                            _buildLiveCheckinsPanel(isScrollableInternal: false),
                          ],
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(28.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: screenSize.width * 0.42,
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  _buildBrandHeader(),
                                  const SizedBox(height: 22),
                                  _buildCameraViewport(height: 240),
                                  const SizedBox(height: 20),
                                  _buildPrimaryCheckInButton(),
                                  const SizedBox(height: 12),
                                  _buildStaffLoginButton(),
                                  const SizedBox(height: 18),
                                  Text(
                                    "$_timeString  •  $_dateString",
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[300],
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 28),
                          Expanded(
                            child: _buildLiveCheckinsPanel(isScrollableInternal: true),
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

  Widget _buildBrandHeader() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildBrandLogo(size: 42),
            const SizedBox(width: 12),
            Flexible(
              child: RichText(
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                  children: const [
                    TextSpan(
                      text: "THE MUSCLES ",
                      style: TextStyle(color: Colors.white),
                    ),
                    TextSpan(
                      text: "GYM",
                      style: TextStyle(color: _crimsonPrimary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 18, height: 1.5, color: _crimsonPrimary.withOpacity(0.85)),
            const SizedBox(width: 8),
            Text(
              "STRONGER THAN YESTERDAY",
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.grey[200],
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(width: 8),
            Container(width: 18, height: 1.5, color: _crimsonPrimary.withOpacity(0.85)),
          ],
        ),
      ],
    );
  }

  Widget _buildCameraViewport({required double height}) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF14161D),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withOpacity(0.85),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: _crimsonPrimary.withOpacity(0.28),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _isCameraInitialized && _cameraController != null
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

            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.95,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.25),
                    ],
                  ),
                ),
              ),
            ),

            IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 26),
                child: CustomPaint(
                  painter: _ScannerBracketsPainter(color: _crimsonPrimary),
                ),
              ),
            ),

            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _timeString,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
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

  Widget _buildPrimaryCheckInButton() {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xFFF43F5E), _crimsonPrimary, _crimsonDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _crimsonPrimary.withOpacity(0.38),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _isVerifying ? null : _verifyFaceAndCheckIn,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isVerifying)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.2,
                    ),
                  )
                else
                  const Icon(
                    Icons.face_retouching_natural_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                const SizedBox(width: 12),
                Text(
                  _isVerifying ? "Recognizing Face..." : "Start Face Check-In",
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStaffLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _openStaffLogin,
        icon: Icon(
          Icons.lock_outline_rounded,
          color: Colors.white.withOpacity(0.9),
          size: 18,
        ),
        label: Text(
          "Staff Dashboard Login",
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: _cardSurface.withOpacity(0.68),
          side: BorderSide(color: Colors.white.withOpacity(0.25), width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveCheckinsPanel({required bool isScrollableInternal}) {
    final header = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 3.5,
              height: 18,
              decoration: BoxDecoration(
                color: _crimsonPrimary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              "LIVE CHECK-INS FEED",
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        IconButton(
          onPressed: _fetchRecentCheckins,
          icon: Icon(
            Icons.refresh_rounded,
            color: Colors.grey[300],
            size: 20,
          ),
          tooltip: "Refresh Feed",
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );

    final listContent = _isLoadingFeed
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: CircularProgressIndicator(color: _crimsonPrimary),
            ),
          )
        : _recentCheckins.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    "No face check-ins recorded yet today.",
                    style: GoogleFonts.inter(
                      color: Colors.grey[400],
                      fontSize: 13,
                    ),
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: !isScrollableInternal,
                physics: isScrollableInternal
                    ? const AlwaysScrollableScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                itemCount: _recentCheckins.length,
                itemBuilder: (context, index) {
                  final checkin = _recentCheckins[index];
                  final memberName = checkin['member_name'] ?? 'Gym Member';
                  final timeIn = checkin['time_in'] ?? 'Just now';
                  final initial = memberName.isNotEmpty
                      ? memberName[0].toUpperCase()
                      : 'M';

                  final avatarColors = [
                    const Color(0xFF93C5FD),
                    const Color(0xFFC4B5FD),
                    const Color(0xFF6EE7B7),
                    const Color(0xFFFCA5A5),
                  ];

                  return _buildCheckinCard(
                    memberName,
                    timeIn,
                    initial,
                    avatarColors[index % avatarColors.length],
                  );
                },
              );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardSurface.withOpacity(0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: isScrollableInternal
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                const SizedBox(height: 16),
                Expanded(child: listContent),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                const SizedBox(height: 14),
                listContent,
              ],
            ),
    );
  }

  Widget _buildCheckinCard(
    String name,
    String timeIn,
    String initial,
    Color avatarColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1E27).withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: avatarColor,
            child: Text(
              initial,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 1,
            height: 36,
            color: Colors.white.withOpacity(0.12),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "Member • Face Verified",
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 12,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeIn,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Colors.white,
                  size: 13,
                ),
                const SizedBox(width: 5),
                Text(
                  "FACE VERIFIED",
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerBracketsPainter extends CustomPainter {
  final Color color;

  _ScannerBracketsPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const double strokeWidth = 3.2;
    const double cornerLen = 26.0;
    const double radius = 12.0;

    final glowPaint = Paint()
      ..color = color.withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 3
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, cornerLen)
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..lineTo(cornerLen, 0)
      ..moveTo(size.width - cornerLen, 0)
      ..lineTo(size.width - radius, 0)
      ..quadraticBezierTo(size.width, 0, size.width, radius)
      ..lineTo(size.width, cornerLen)
      ..moveTo(0, size.height - cornerLen)
      ..lineTo(0, size.height - radius)
      ..quadraticBezierTo(0, size.height, radius, size.height)
      ..lineTo(cornerLen, size.height)
      ..moveTo(size.width - cornerLen, size.height)
      ..lineTo(size.width - radius, size.height)
      ..quadraticBezierTo(size.width, size.height, size.width, size.height - radius)
      ..lineTo(size.width, size.height - cornerLen);

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}