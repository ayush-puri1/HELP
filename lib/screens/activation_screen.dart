import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/emergency_handler.dart';
import '../services/emergency_contacts_repository.dart';

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  int _timeRemaining = 38;
  bool _isRecording = false;
  bool _isStopped = false;
  EmergencyHandler? _emergencyHandler;

  @override
  void initState() {
    super.initState();
    _startActivation();
  }

  Future<void> _startActivation() async {
    if (!mounted) return;
    final repository = Provider.of<EmergencyContactsRepository>(context, listen: false);
    _emergencyHandler = EmergencyHandler();
    
    // Enable connectivity
    await _emergencyHandler!.enableConnectivity();
    
    // Start recording
    await _emergencyHandler!.startRecording();
    
    setState(() {
      _isRecording = true;
    });

    // Countdown timer
    for (int i = 38; i > 0 && !_isStopped; i--) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted && !_isStopped) {
        setState(() {
          _timeRemaining = i;
        });
      }
    }

    // Timer expired - trigger emergency actions
    if (!_isStopped && _isRecording && mounted) {
      await _emergencyHandler!.stopRecording();
      await _emergencyHandler!.triggerEmergencyActions(
        repository.contacts,
      );
      setState(() {
        _isRecording = false;
      });
    }
  }

  void _stopActivation() {
    setState(() {
      _isStopped = true;
      _isRecording = false;
    });
    _emergencyHandler?.stopRecording();
    context.go('/contacts');
  }

  @override
  void dispose() {
    if (_isRecording) {
      _emergencyHandler?.stopRecording();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB71C1C), // Red background
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$_timeRemaining',
                style: const TextStyle(
                  fontSize: 120,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Text(
                'seconds remaining',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              if (_isRecording) ...[
                const SizedBox(height: 16),
                const Text(
                  'Recording...',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: 200,
                height: 200,
                child: ElevatedButton(
                  onPressed: _stopActivation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFB71C1C),
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(16),
                  ),
                  child: const Text(
                    'STOP',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Press STOP to cancel emergency',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

