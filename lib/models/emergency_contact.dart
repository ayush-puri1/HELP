import 'package:json_annotation/json_annotation.dart';

part 'emergency_contact.g.dart';

@JsonSerializable()
class EmergencyContact {
  final int id;
  final String name;
  final String phoneNumber;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      _$EmergencyContactFromJson(json);

  Map<String, dynamic> toJson() => _$EmergencyContactToJson(this);

  EmergencyContact copyWith({
    int? id,
    String? name,
    String? phoneNumber,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }
}

