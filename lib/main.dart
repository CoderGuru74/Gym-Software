import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/admin/member_verification_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://woiuesrsyyuuigrftxmi.supabase.co',
    publishableKey: 'sb_publishable_-EYboa0UgiWY8mC7tmAWlg_CTn1ifaU',
  );

  runApp(const MuscleGymApp());
}

final supabase = Supabase.instance.client;

class MuscleGymApp extends StatelessWidget {
  const MuscleGymApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Muscles Gym Software',
      debugShowCheckedModeBanner: false,
      home: const MemberVerificationScreen(),
    );
  }
}