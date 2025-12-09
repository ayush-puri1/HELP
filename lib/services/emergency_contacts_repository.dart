import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/emergency_contact.dart';

class EmergencyContactsRepository extends ChangeNotifier {
  List<EmergencyContact> _contacts = [];
  
  List<EmergencyContact> get contacts => _contacts;

  EmergencyContactsRepository() {
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsJson = prefs.getString('emergency_contacts');
    
    if (contactsJson != null) {
      try {
        final List<dynamic> decoded = json.decode(contactsJson);
        _contacts = decoded
            .map((contact) => EmergencyContact.fromJson(contact))
            .toList();
        notifyListeners();
      } catch (e) {
        debugPrint('Error loading contacts: $e');
      }
    }
  }

  Future<void> addContact(String name, String phoneNumber) async {
    final newContact = EmergencyContact(
      id: DateTime.now().millisecondsSinceEpoch,
      name: name,
      phoneNumber: phoneNumber,
    );
    
    _contacts.insert(0, newContact);
    await _saveContacts();
    notifyListeners();
  }

  Future<void> removeContact(EmergencyContact contact) async {
    _contacts.removeWhere((c) => c.id == contact.id);
    await _saveContacts();
    notifyListeners();
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsJson = json.encode(
      _contacts.map((contact) => contact.toJson()).toList(),
    );
    await prefs.setString('emergency_contacts', contactsJson);
  }
}

