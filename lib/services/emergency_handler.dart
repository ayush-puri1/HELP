import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/emergency_contact.dart';

class EmergencyHandler {
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _audioFilePath;
  bool _isRecording = false;

  Future<void> enableConnectivity() async {
    try {
      // Note: Direct WiFi/Mobile data control requires platform channels
      // This opens settings for user to enable manually
      if (Platform.isAndroid) {
        // For Android, we can try to open WiFi settings
        const platform = MethodChannel('com.example.voicerecognition/connectivity');
        try {
          await platform.invokeMethod('enableWiFi');
        } catch (e) {
          // Fallback: Open settings
          await openAppSettings();
        }
      }
    } catch (e) {
      print('Error enabling connectivity: $e');
    }
  }

  Future<void> startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final appDir = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        _audioFilePath = '${appDir.path}/emergency_$timestamp.m4a';
        
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: _audioFilePath!,
        );
        _isRecording = true;
      }
    } catch (e) {
      print('Error starting recording: $e');
    }
  }

  Future<void> stopRecording() async {
    if (_isRecording) {
      try {
        await _audioRecorder.stop();
        _isRecording = false;
      } catch (e) {
        print('Error stopping recording: $e');
      }
    }
  }

  Future<void> triggerEmergencyActions(List<EmergencyContact> contacts) async {
    try {
      // Get location
      final location = await _getCurrentLocation();

      // Send to emergency contacts
      for (final contact in contacts) {
        await _sendEmergencyMessage(contact, location);
      }

      // Call emergency services (112)
      await _callEmergencyServices();
    } catch (e) {
      print('Error in emergency actions: $e');
      // Still try to call emergency services
      try {
        await _callEmergencyServices();
      } catch (ex) {
        print('Failed to call emergency services: $ex');
      }
    }
  }

  Future<String> _getCurrentLocation() async {
    try {
      // Check permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return 'Location services are disabled';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return 'Location permissions denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return 'Location permissions permanently denied';
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final googleMapsLink =
          'https://www.google.com/maps?q=${position.latitude},${position.longitude}';

      return 'Latitude: ${position.latitude}\n'
          'Longitude: ${position.longitude}\n'
          'Accuracy: ${position.accuracy}m\n'
          'Google Maps: $googleMapsLink\n'
          'Time: ${DateTime.now().toString()}';
    } catch (e) {
      return 'Error getting location: $e';
    }
  }

  Future<void> _sendEmergencyMessage(
    EmergencyContact contact,
    String location,
  ) async {
    try {
      final timestamp = DateTime.now().toString();
      final message = '🚨 EMERGENCY ALERT! 🚨\n\n'
          'This is an automated emergency message from HELP app.\n\n'
          'Location:\n$location\n\n'
          'Time: $timestamp\n\n'
          'Please respond immediately!';

      // Send SMS
      final smsUri = Uri.parse('sms:${contact.phoneNumber}?body=${Uri.encodeComponent(message)}');
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      }

      // Also try to call the contact
      await Future.delayed(const Duration(seconds: 1));
      final callUri = Uri.parse('tel:${contact.phoneNumber}');
      if (await canLaunchUrl(callUri)) {
        await launchUrl(callUri);
      }
    } catch (e) {
      print('Error sending emergency message: $e');
    }
  }

  Future<void> _callEmergencyServices() async {
    try {
      final callUri = Uri.parse('tel:112');
      if (await canLaunchUrl(callUri)) {
        await launchUrl(callUri);
      } else {
        // Fallback to dialer
        final dialUri = Uri.parse('tel:112');
        await launchUrl(dialUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Error calling emergency services: $e');
    }
  }
  

