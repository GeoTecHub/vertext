import 'package:flutter/material.dart';

class ToleranceViewModel extends ChangeNotifier {
  // Quality Check
  String solution = "FIXED"; // FIXED, FLOAT, DGNSS, SINGLE
  double hrms = 0.05;
  double vrms = 0.10;
  double pdop = 3.0;
  double age = 5.0; // Differential Age

  // Filters (Unlimited = -1 or null, but UI shows Unlimited)
  int usedSatellites = 0; // 0 = unlimited/ignored
  double tiltAngle = 0; // 0 = unlimited

  // Averaging
  int surveyDelay = 0;
  int averagePoints = 5; // How many epochs to average

  // Checking Logic
  bool checkQuality({
    required String? currentSol,
    required double? currentHrms,
    required double? currentVrms,
    required double? currentPdop,
    required double? currentAge,
  }) {
    // 1. Solution
    // Hierarchy: FIXED > FLOAT > DGNSS > SINGLE
    // If requirement is FIXED, we accept only FIXED.
    // If FLOAT, we accept FIXED or FLOAT.
    if (solution == "FIXED" && currentSol != "FIXED") return false;
    if (solution == "FLOAT" &&
        (currentSol != "FIXED" && currentSol != "FLOAT")) {
      return false;
    }

    if (currentHrms != null && currentHrms > hrms) return false;
    if (currentVrms != null && currentVrms > vrms) return false;
    if (currentPdop != null && currentPdop > pdop) return false;
    if (currentAge != null && currentAge > age) return false;

    return true;
  }

  // Setters
  void update({
    String? solution,
    double? hrms,
    double? vrms,
    double? pdop,
    double? age,
    int? averagePoints,
  }) {
    if (solution != null) this.solution = solution;
    if (hrms != null) this.hrms = hrms;
    if (vrms != null) this.vrms = vrms;
    if (pdop != null) this.pdop = pdop;
    if (age != null) this.age = age;
    if (averagePoints != null) this.averagePoints = averagePoints;
    notifyListeners();
  }
}
