import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

class ContactService {
  /// Request contacts permission
  Future<bool> requestPermission() async {
    final status = await Permission.contacts.status;
    if (status.isGranted) {
      return true;
    }
    
    if (status.isDenied) {
      final result = await Permission.contacts.request();
      return result.isGranted;
    }
    
    return false;
  }

  /// Check if contacts permission is granted
  Future<bool> hasPermission() async {
    final status = await Permission.contacts.status;
    return status.isGranted;
  }

  /// Get all contacts from device
  Future<List<Contact>> getContacts() async {
    if (!await hasPermission()) {
      if (!await requestPermission()) {
        throw Exception('Contacts permission denied');
      }
    }

    try {
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withThumbnail: false,
      );
      // Sort by name
      contacts.sort((a, b) {
        final nameA = a.displayName.toLowerCase();
        final nameB = b.displayName.toLowerCase();
        return nameA.compareTo(nameB);
      });
      return contacts;
    } catch (e) {
      throw Exception('Failed to fetch contacts: $e');
    }
  }

  /// Search contacts by name
  Future<List<Contact>> searchContacts(String query) async {
    final contacts = await getContacts();
    final lowerQuery = query.toLowerCase();
    return contacts.where((contact) {
      final name = contact.displayName.toLowerCase();
      final emails = contact.emails.map((e) => e.address.toLowerCase()).join(' ');
      final phones = contact.phones.map((p) => p.number).join(' ');
      return name.contains(lowerQuery) ||
          emails.contains(lowerQuery) ||
          phones.contains(lowerQuery);
    }).toList();
  }

  /// Get primary email from contact
  String? getPrimaryEmail(Contact contact) {
    if (contact.emails.isEmpty) return null;
    return contact.emails.first.address;
  }

  /// Get primary phone from contact
  String? getPrimaryPhone(Contact contact) {
    if (contact.phones.isEmpty) return null;
    return contact.phones.first.number;
  }

  /// Format phone number (remove spaces, dashes, etc.)
  String formatPhoneNumber(String phone) {
    return phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
  }
}

