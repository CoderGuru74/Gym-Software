import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/supabase_service.dart';

class AdminAttendanceView extends StatefulWidget {
  const AdminAttendanceView({super.key});

  @override
  State<AdminAttendanceView> createState() => _AdminAttendanceViewState();
}

class _AdminAttendanceViewState extends State<AdminAttendanceView> {
  final _supabaseService = SupabaseService();
  List _allLogs = [];
  bool _isLoading = true;

  /// Currently selected date being viewed (defaults to Today)
  late DateTime _selectedDate;

  /// Tracks real-world today to detect midnight day rollover
  late DateTime _todayDate;

  /// In-memory session fallback so cutoff survives page switches immediately
  static String? _cachedCutoffDayKey;
  static DateTime? _cachedCutoffTime;

  DateTime? _manualSessionCutoff;
  Timer? _midnightWatcher;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _todayDate = DateTime(now.year, now.month, now.day);
    _selectedDate = _todayDate;
    _initCutoffAndFetch();
    _startDayRolloverWatcher();
  }

  @override
  void dispose() {
    _midnightWatcher?.cancel();
    super.dispose();
  }

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _isSameCalendarDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get _isViewingToday => _isSameCalendarDay(_selectedDate, _todayDate);

  /// Loads any persisted "Start New Day Log" cutoff for today so navigating
  /// to another page and returning never brings back cleared logs.
  Future<void> _initCutoffAndFetch() async {
    final todayKey = _dayKey(_todayDate);

    // 1. Restore from fast static memory if available for today
    if (_cachedCutoffDayKey == todayKey && _cachedCutoffTime != null) {
      _manualSessionCutoff = _cachedCutoffTime;
    } else {
      // 2. Restore from SharedPreferences for today
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedDay = prefs.getString('attendance_cutoff_day');
        final savedIso = prefs.getString('attendance_cutoff_iso');
        if (savedDay == todayKey && savedIso != null) {
          final parsed = DateTime.tryParse(savedIso);
          if (parsed != null) {
            _manualSessionCutoff = parsed;
            _cachedCutoffDayKey = todayKey;
            _cachedCutoffTime = parsed;
          }
        } else {
          // Clear stale cutoff from previous days
          await prefs.remove('attendance_cutoff_day');
          await prefs.remove('attendance_cutoff_iso');
          _cachedCutoffDayKey = null;
          _cachedCutoffTime = null;
          _manualSessionCutoff = null;
        }
      } catch (_) {}
    }

    await _fetchAttendance();
  }

  Future<void> _saveCutoffForToday(DateTime cutoff) async {
    final todayKey = _dayKey(_todayDate);
    _cachedCutoffDayKey = todayKey;
    _cachedCutoffTime = cutoff;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('attendance_cutoff_day', todayKey);
      await prefs.setString('attendance_cutoff_iso', cutoff.toIso8601String());
    } catch (_) {}
  }

  /// Automatically rolls over to a fresh live log when the calendar day ends (midnight)
  void _startDayRolloverWatcher() {
    _midnightWatcher = Timer.periodic(const Duration(seconds: 30), (_) async {
      final now = DateTime.now();
      final actualToday = DateTime(now.year, now.month, now.day);
      if (!_isSameCalendarDay(actualToday, _todayDate)) {
        final wasOnToday = _isViewingToday;
        _cachedCutoffDayKey = null;
        _cachedCutoffTime = null;

        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('attendance_cutoff_day');
          await prefs.remove('attendance_cutoff_iso');
        } catch (_) {}

        if (!mounted) return;
        setState(() {
          _todayDate = actualToday;
          if (wasOnToday) {
            _selectedDate = actualToday;
          }
          _manualSessionCutoff = null;
        });
        _fetchAttendance();
      }
    });
  }

  DateTime? _extractLogTimestamp(dynamic log) {
    final candidates = [
      log['created_at'],
      log['check_in_time'],
      log['timestamp'],
      log['date'],
      log['time_in'],
    ];

    for (final raw in candidates) {
      if (raw == null) continue;
      final str = raw.toString().trim();
      if (str.isEmpty) continue;

      final parsed = DateTime.tryParse(str);
      if (parsed != null) return parsed.toLocal();

      // Handle time-only strings like "09:42:15" or "09:42 AM" by assuming today
      final timeMatch = RegExp(
        r'^(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)?$',
        caseSensitive: false,
      ).firstMatch(str);
      if (timeMatch != null) {
        int hour = int.tryParse(timeMatch.group(1)!) ?? 0;
        final minute = int.tryParse(timeMatch.group(2)!) ?? 0;
        final second = int.tryParse(timeMatch.group(3) ?? '0') ?? 0;
        final meridiem = timeMatch.group(4)?.toUpperCase();

        if (meridiem == 'PM' && hour < 12) hour += 12;
        if (meridiem == 'AM' && hour == 12) hour = 0;

        return DateTime(
          _todayDate.year,
          _todayDate.month,
          _todayDate.day,
          hour,
          minute,
          second,
        );
      }
    }
    return null;
  }

  List get _filteredLogsForSelectedDate {
    return _allLogs.where((log) {
      final ts = _extractLogTimestamp(log);

      // If a row has no parseable date at all, only show it on Today if no cutoff exists
      if (ts == null) {
        return _isViewingToday && _manualSessionCutoff == null;
      }

      // Must match the selected calendar date
      if (!_isSameCalendarDay(ts, _selectedDate)) {
        return false;
      }

      // If viewing Today and user tapped "Start New Day Log", hide entries before that cutoff
      if (_isViewingToday &&
          _manualSessionCutoff != null &&
          ts.isBefore(_manualSessionCutoff!)) {
        return false;
      }

      return true;
    }).toList();
  }

  String _formatDateLabel(DateTime date) {
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
    final base =
        '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
    if (_isSameCalendarDay(date, _todayDate)) {
      return 'Today, $base';
    }
    final yesterday = _todayDate.subtract(const Duration(days: 1));
    if (_isSameCalendarDay(date, yesterday)) {
      return 'Yesterday, $base';
    }
    return base;
  }

  String _formatTimeOnly(DateTime dt) {
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$min $period';
  }

  Future<void> _fetchAttendance() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final data = await _supabaseService.getAttendanceLogs();
      if (!mounted) return;
      setState(() {
        _allLogs = data is List ? data : [];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: _todayDate,
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  void _goToPreviousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
  }

  void _goToNextDay() {
    if (_isViewingToday) return;
    final next = _selectedDate.add(const Duration(days: 1));
    setState(() {
      _selectedDate = next.isAfter(_todayDate) ? _todayDate : next;
    });
  }

  Future<void> _confirmStartNewDayLog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          "Start New Live Attendance Log?",
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        content: Text(
          "This will clear earlier check-ins from today's live feed and start a fresh log from right now. Even if you switch pages, earlier check-ins will stay hidden from today's live log.\n\nAll past check-ins remain safely saved in each member's Attendance History.",
          style: GoogleFonts.inter(
            fontSize: 13.5,
            height: 1.45,
            color: const Color(0xFF475569),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              "Cancel",
              style: GoogleFonts.inter(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              "Start Fresh Log",
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final now = DateTime.now();
      await _saveCutoffForToday(now);
      if (!mounted) return;
      setState(() {
        _todayDate = DateTime(now.year, now.month, now.day);
        _selectedDate = _todayDate;
        _manualSessionCutoff = now;
      });
      await _fetchAttendance();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Started new live attendance log at ${_formatTimeOnly(now)}",
          ),
          backgroundColor: const Color(0xFF0F172A),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1E293B);
    final visibleLogs = _filteredLogsForSelectedDate;
    final isCompact = MediaQuery.of(context).size.width < 760;

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
                  _isViewingToday
                      ? "LIVE ATTENDANCE LOG"
                      : "ATTENDANCE LOG ARCHIVE",
                  style: GoogleFonts.inter(
                    fontSize: isCompact ? 18 : 22,
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isViewingToday
                      ? (_manualSessionCutoff != null
                          ? "Active session started at ${_formatTimeOnly(_manualSessionCutoff!)} • Auto-resets at midnight"
                          : "Real-time biometric check-in stream • Auto-starts new log at midnight")
                      : "Viewing historical check-ins for ${_formatDateLabel(_selectedDate)}",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                // Date Selector Control (< Previous | Date Picker | Next >)
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _goToPreviousDay,
                        icon: const Icon(
                          Icons.chevron_left_rounded,
                          size: 20,
                          color: primaryColor,
                        ),
                        tooltip: "Previous Day",
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        constraints: const BoxConstraints(),
                      ),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                                color: primaryColor,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                _formatDateLabel(_selectedDate),
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _isViewingToday ? null : _goToNextDay,
                        icon: Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: _isViewingToday
                              ? Colors.grey[350]
                              : primaryColor,
                        ),
                        tooltip: "Next Day",
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                if (!_isViewingToday)
                  TextButton(
                    onPressed: () {
                      setState(() => _selectedDate = _todayDate);
                    },
                    child: Text(
                      "Back to Today",
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0284C7),
                      ),
                    ),
                  ),

                if (_isViewingToday)
                  OutlinedButton.icon(
                    onPressed: _confirmStartNewDayLog,
                    icon: const Icon(
                      Icons.restart_alt_rounded,
                      size: 17,
                      color: primaryColor,
                    ),
                    label: Text(
                      "Start New Day Log",
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),

                IconButton(
                  onPressed: _fetchAttendance,
                  icon: const Icon(Icons.refresh_rounded, color: primaryColor),
                  tooltip: "Refresh Log",
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
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
                    child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
                  )
                : visibleLogs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_available_rounded,
                              size: 42,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _isViewingToday
                                  ? "No attendance logs recorded yet in this live session."
                                  : "No attendance logs found for ${_formatDateLabel(_selectedDate)}.",
                              style: GoogleFonts.inter(
                                color: Colors.grey[600],
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isViewingToday
                                  ? "New check-ins from the face kiosk will appear here live."
                                  : "Use the arrows above to switch to another date.",
                              style: GoogleFonts.inter(
                                color: Colors.grey[400],
                                fontSize: 12,
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
                                    "Check-In Time",
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
                                    "Status",
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
                              itemCount: visibleLogs.length,
                              itemBuilder: (context, index) {
                                final log = visibleLogs[index];
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
                                          log['member_name'] ?? '',
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
                                          log['time_in'] ?? '',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green[50],
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              log['status'] ?? 'CHECK-IN',
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green[700],
                                              ),
                                            ),
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