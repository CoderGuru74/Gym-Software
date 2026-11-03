import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  // Expose the client instance publicly so views and dialogs can access it
  SupabaseClient get client => Supabase.instance.client;

  // ==================== MEMBERS ====================

  Future<List> getMembers() async {
    try {
      final response = await client
          .from('members')
          .select()
          .order('created_at', ascending: false);
      return response;
    } catch (e) {
      return [];
    }
  }

  Future<void> addMember({
    required String name,
    required String phone,
    String? email,
    required String plan,
  }) async {
    try {
      await client.from('members').insert({
        'name': name,
        'phone': phone,
        'email': email,
        'plan': plan,
        'status': 'ACTIVE',
        'days_left': 30,
      });
    } catch (e) {
      throw Exception('Database write failed: $e');
    }
  }

  // ==================== ATTENDANCE ====================

  Future<List> getAttendanceLogs() async {
    try {
      final response = await client
          .from('attendance')
          .select()
          .order('date', ascending: false);
      return response;
    } catch (e) {
      return [];
    }
  }

  Future<void> logAttendance({required String memberName}) async {
    try {
      final timeString = DateTime.now().toLocal().toString().substring(11, 19);
      await client.from('attendance').insert({
        'member_name': memberName,
        'time_in': timeString,
        'status': 'CHECK-IN',
      });
    } catch (e) {
      throw Exception('Failed to log attendance: $e');
    }
  }

  // ==================== PAYMENTS ====================

  Future<List> getPayments() async {
    try {
      final response = await client
          .from('payments')
          .select()
          .order('due_date', ascending: true);
      return response;
    } catch (e) {
      return [];
    }
  }
}