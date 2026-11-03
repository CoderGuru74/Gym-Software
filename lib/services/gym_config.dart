import 'dart:io';
import 'package:flutter/material.dart';

class GymConfig extends ChangeNotifier {
  static final GymConfig _instance = GymConfig._internal();
  factory GymConfig() => _instance;
  GymConfig._internal();

  String gymName = "APEX FITNESS";
  String address = "Plot 24, Main Road, Patna, Bihar";
  String phone = "+91 98765 00000";
  String email = "hello@apexfitness.in";
  File? logoFile;

  void updateSettings({
    required String name,
    required String addr,
    required String ph,
    required String em,
    File? logo,
  }) {
    gymName = name.toUpperCase();
    address = addr;
    phone = ph;
    email = em;
    if (logo != null) {
      logoFile = logo;
    }
    notifyListeners(); // Tells all listening screens to rebuild with new name/logo
  }
}