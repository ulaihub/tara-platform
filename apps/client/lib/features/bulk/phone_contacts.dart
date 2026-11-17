import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_core/phone/phone_format.dart';

/// Un contact du téléphone avec un numéro de mobile camerounais (9 chiffres nationaux).
@immutable
class PhoneContact {
  const PhoneContact(this.name, this.phone);
  final String name;
  final String phone;
}

/// Contacts du téléphone, lus sur place : rien ne part tant que l'expéditeur n'a pas coché
/// et ajouté un client (remplacé dans les tests).
abstract class PhoneContacts {
  /// Demande l'accès en lecture ; vrai s'il est donné (même partiel, iOS 18).
  Future<bool> request();

  /// Contacts qui ont un mobile camerounais, un par numéro, triés par nom.
  Future<List<PhoneContact>> mobiles();

  Future<void> openSettings();
}

class DevicePhoneContacts implements PhoneContacts {
  const DevicePhoneContacts();

  @override
  Future<bool> request() async {
    final status = await FlutterContacts.permissions.request(PermissionType.read);
    return status == PermissionStatus.granted || status == PermissionStatus.limited;
  }

  @override
  Future<List<PhoneContact>> mobiles() async {
    final contacts = await FlutterContacts.getAll(properties: {ContactProperty.name, ContactProperty.phone});
    final byPhone = <String, PhoneContact>{};
    for (final contact in contacts) {
      final name = (contact.displayName ?? '').trim();
      if (name.isEmpty) continue;
      for (final phone in contact.phones) {
        final national = nationalMobile(phone.number);
        if (national != null) byPhone.putIfAbsent(national, () => PhoneContact(name, national));
      }
    }
    return byPhone.values.toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  @override
  Future<void> openSettings() => FlutterContacts.permissions.openSettings();
}

/// « +237 6 90 11 22 33 », « 00237690112233 », « 690112233 » → « 690112233 » ; null si ce
/// n'est pas un mobile camerounais.
String? nationalMobile(String input) {
  var digits = digitsOf(input);
  if (digits.startsWith('00237')) digits = digits.substring(5);
  if (digits.startsWith('237') && digits.length == 12) digits = digits.substring(3);
  return isCameroonMobile(digits) ? digits : null;
}

final phoneContactsProvider = Provider<PhoneContacts>((ref) => const DevicePhoneContacts());
