import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_state.dart';
import '../models/risk_report.dart';

class LocalAppStateStore {
  LocalAppStateStore._();

  static final LocalAppStateStore instance = LocalAppStateStore._();

  static const _latestChatReportKey = 'latest_chat_report';
  static const _communityEligibilityKey = 'community_flag_eligibility';
  static const _lastCommunityLookupKey = 'last_community_lookup';
  static const _settingsKey = 'app_settings';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<void> saveLatestChatReport(RiskReport report) async {
    final prefs = await _prefs;
    await prefs.setString(_latestChatReportKey, jsonEncode(report.toJson()));
  }

  Future<RiskReport?> loadLatestChatReport() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_latestChatReportKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      return RiskReport.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCommunityFlagEligibility(
    CommunityFlagEligibility eligibility,
  ) async {
    final prefs = await _prefs;
    await prefs.setString(_communityEligibilityKey, eligibility.encode());
  }

  Future<CommunityFlagEligibility?> loadCommunityFlagEligibility() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_communityEligibilityKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      return CommunityFlagEligibility.decode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCommunityFlagEligibility() async {
    final prefs = await _prefs;
    await prefs.remove(_communityEligibilityKey);
  }

  Future<void> saveLastCommunityLookup(LastCommunityLookup lookup) async {
    final prefs = await _prefs;
    await prefs.setString(_lastCommunityLookupKey, lookup.encode());
  }

  Future<LastCommunityLookup?> loadLastCommunityLookup() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_lastCommunityLookupKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      return LastCommunityLookup.decode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<AppSettings> loadSettings() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_settingsKey);
    if (raw == null || raw.isEmpty) {
      return const AppSettings();
    }

    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await _prefs;
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }
}
