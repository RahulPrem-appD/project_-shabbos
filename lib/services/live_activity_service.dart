import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:live_activities/live_activities.dart';

class LiveActivityService {
  static final LiveActivityService _instance = LiveActivityService._internal();
  factory LiveActivityService() => _instance;
  LiveActivityService._internal();

  final _liveActivitiesPlugin = LiveActivities();
  String? _currentActivityId;
  bool _isInitialized = false;

  static const String _activityType = 'ShabbosCountdown';

  /// Initialize the Live Activities service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    if (!Platform.isIOS) {
      debugPrint('LiveActivityService: Only supported on iOS');
      return;
    }

    try {
      await _liveActivitiesPlugin.init(
        appGroupId: 'group.com.shabbos.shabbosApp',
      );
      _isInitialized = true;
      debugPrint('LiveActivityService: Initialized successfully');
    } catch (e) {
      debugPrint('LiveActivityService: Initialization failed: $e');
    }
  }

  /// Check if Live Activities are supported
  Future<bool> areActivitiesEnabled() async {
    if (!Platform.isIOS) return false;
    
    try {
      return await _liveActivitiesPlugin.areActivitiesEnabled();
    } catch (e) {
      debugPrint('LiveActivityService: Error checking if enabled: $e');
      return false;
    }
  }

  /// Start a countdown Live Activity for candle lighting
  Future<String?> startCandleLightingCountdown({
    required DateTime candleLightingTime,
    required String eventName,
    required bool isYomTov,
  }) async {
    if (!Platform.isIOS) {
      debugPrint('LiveActivityService: Only supported on iOS');
      return null;
    }

    try {
      await initialize();

      // Check if activities are enabled
      final enabled = await areActivitiesEnabled();
      if (!enabled) {
        debugPrint('LiveActivityService: Live Activities not enabled');
        return null;
      }

      // End any existing activity first
      await endCurrentActivity();

      // Create the activity data
      final Map<String, dynamic> data = {
        'candleLightingTime': candleLightingTime.millisecondsSinceEpoch,
        'eventName': eventName,
        'isYomTov': isYomTov,
        'eventType': isYomTov ? 'yomtov' : 'shabbos',
      };

      debugPrint('LiveActivityService: Starting Live Activity with data: $data');

      // Start the Live Activity with activity ID and data
      _currentActivityId = await _liveActivitiesPlugin.createActivity(
        _activityType,
        data,
      );

      debugPrint('LiveActivityService: Started activity with ID: $_currentActivityId');
      return _currentActivityId;
    } catch (e) {
      debugPrint('LiveActivityService: Error starting activity: $e');
      return null;
    }
  }

  /// Update the current Live Activity
  Future<void> updateActivity({
    required DateTime candleLightingTime,
    required String eventName,
    required bool isYomTov,
  }) async {
    if (!Platform.isIOS || _currentActivityId == null) return;

    try {
      final Map<String, dynamic> data = {
        'candleLightingTime': candleLightingTime.millisecondsSinceEpoch,
        'eventName': eventName,
        'isYomTov': isYomTov,
        'eventType': isYomTov ? 'yomtov' : 'shabbos',
      };

      await _liveActivitiesPlugin.updateActivity(
        _currentActivityId!,
        data,
      );

      debugPrint('LiveActivityService: Updated activity $_currentActivityId');
    } catch (e) {
      debugPrint('LiveActivityService: Error updating activity: $e');
    }
  }

  /// End the current Live Activity
  Future<void> endCurrentActivity() async {
    if (!Platform.isIOS) return;

    try {
      if (_currentActivityId != null) {
        await _liveActivitiesPlugin.endActivity(_currentActivityId!);
        debugPrint('LiveActivityService: Ended activity $_currentActivityId');
        _currentActivityId = null;
      }

      // Also end all activities to be safe
      await _liveActivitiesPlugin.endAllActivities();
    } catch (e) {
      debugPrint('LiveActivityService: Error ending activity: $e');
    }
  }

  /// Get all current activities
  Future<List<String>> getAllActivities() async {
    if (!Platform.isIOS) return [];

    try {
      final activities = await _liveActivitiesPlugin.getAllActivitiesIds();
      return activities;
    } catch (e) {
      debugPrint('LiveActivityService: Error getting activities: $e');
      return [];
    }
  }
}

