import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class BackgroundListeningService extends ChangeNotifier {
  static final BackgroundListeningService _instance = BackgroundListeningService._internal();
  factory BackgroundListeningService() => _instance;
  BackgroundListeningService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  final List<DateTime> _keywordDetections = [];
  static const String _keyword = 'help';
  static const int _requiredCount = 3;
  static const Duration _timeWindow = Duration(minutes: 1);
  
  bool _isListening = false;
  int _keywordCount = 0;

  bool get isListening => _isListening;
  int get keywordCount => _keywordCount;

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();
    
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'background_listening_channel',
        initialNotificationTitle: 'Voice Recognition Active',
        initialNotificationContent: 'Listening for help...',
        foregroundServiceNotificationId: 1,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  Future<void> startListening() async {
    if (_isListening) return;

    // Check permissions
    final micPermission = await Permission.microphone.request();
    if (!micPermission.isGranted) {
      debugPrint('Microphone permission not granted');
      return;
    }

    // Initialize speech recognition
    bool available = await _speech.initialize(
      onError: (error) => debugPrint('Speech recognition error: $error'),
      onStatus: (status) => debugPrint('Speech recognition status: $status'),
    );

    if (!available) {
      debugPrint('Speech recognition not available');
      return;
    }

    _isListening = true;
    _keywordCount = 0;
    notifyListeners();

    // Start listening
    _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          _processResult(result.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      localeId: 'en_US',
      listenMode: stt.ListenMode.confirmation,
    );

    // Start background service
    final service = FlutterBackgroundService();
    await service.startService();
  }

  void _processResult(String recognizedWords) {
    final lowerWords = recognizedWords.toLowerCase();
    if (lowerWords.contains(_keyword)) {
      final now = DateTime.now();
      _keywordDetections.add(now);

      // Clean old detections outside time window
      _keywordDetections.removeWhere(
        (detection) => now.difference(detection) > _timeWindow,
      );

      _keywordCount = _keywordDetections.length;
      notifyListeners();

      debugPrint('Keyword "$_keyword" detected. Count: $_keywordCount');

      // Check if activation threshold reached
      if (_keywordDetections.length >= _requiredCount) {
        debugPrint('Activation triggered!');
        _triggerActivation();
        _keywordDetections.clear();
        _keywordCount = 0;
        notifyListeners();
      }
    }
  }

  void _triggerActivation() {
    // Navigate to activation screen
    // Note: This requires a global navigator key or context
    debugPrint('Activation triggered - navigating to activation screen');
    // The navigation will be handled by listening to this event in main.dart
    final service = FlutterBackgroundService();
    service.invoke('activate');
  }

  Future<void> stopListening() async {
    if (!_isListening) return;

    await _speech.stop();
    _isListening = false;
    _keywordDetections.clear();
    _keywordCount = 0;
    notifyListeners();

    final service = FlutterBackgroundService();
    await service.invoke('stop');
  }

  void resetCounts() {
    _keywordDetections.clear();
    _keywordCount = 0;
    notifyListeners();
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('activate').listen((event) {
      if (event != null) {
        // Navigate to activation screen
        // This requires a global navigator key
        debugPrint('Activation triggered from background service');
      }
    });

    service.on('stop').listen((event) {
      service.stopSelf();
    });
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}

