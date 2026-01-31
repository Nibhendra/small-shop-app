import 'package:flutter/material.dart';

class UserProvider extends ChangeNotifier {
  String _name = "User";
  String _shopName = "My Shop";

  String _gender = '';
  String _address = '';

  String _id = ""; // Firebase uid
  String _username = ""; // email or phone (kept for UI compatibility)
  String _email = "";
  String _phone = "";

  String get id => _id;
  String get username => _username;
  String get email => _email;
  String get phone => _phone;
  String get name => _name;
  String get shopName => _shopName;
  String get gender => _gender;
  String get address => _address;

  void setUser(
    String id,
    String username,
    String name,
    String? shopName,
    String? phone,
  ) {
    _id = id;
    _username = username;
    _name = name.isNotEmpty ? name : "Admin";
    if (shopName != null && shopName.isNotEmpty) {
      _shopName = shopName;
    }
    if (phone != null && phone.isNotEmpty) {
      _phone = phone;
    }
    notifyListeners();
  }

  void setFromFirebase({
    required String uid,
    String? displayName,
    String? email,
    String? phone,
    String? shopName,
    String? gender,
    String? address,
  }) {
    _id = uid;
    _email = email ?? '';
    _phone = phone ?? '';
    _username = (email?.isNotEmpty == true)
        ? email!
        : (phone?.isNotEmpty == true)
            ? phone!
            : uid;
    _name = (displayName?.isNotEmpty == true) ? displayName! : 'User';
    if (shopName != null && shopName.isNotEmpty) {
      _shopName = shopName;
    }

    if (gender != null) {
      _gender = gender;
    }
    if (address != null) {
      _address = address;
    }
    notifyListeners();
  }

  void clear() {
    _id = '';
    _username = '';
    _email = '';
    _phone = '';
    _name = 'User';
    _shopName = 'My Shop';
    _gender = '';
    _address = '';
    notifyListeners();
  }

  void updateProfile(String name, String shopName) {
    _name = name;
    _shopName = shopName;
    notifyListeners();
  }

  void updateProfileExtended({
    required String name,
    required String shopName,
    String? email,
    String? phone,
    String? gender,
    String? address,
  }) {
    _name = name;
    _shopName = shopName;
    if (email != null) _email = email;
    if (phone != null) _phone = phone;
    if (gender != null) _gender = gender;
    if (address != null) _address = address;
    notifyListeners();
  }
}
