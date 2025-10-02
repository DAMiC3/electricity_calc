enum UserRole { customer, manager, staff }

class UserProfile {
  final String name;
  final String? language; // ISO code hint
  final String? homeAddress;
  final double? homeLat;
  final double? homeLng;
  final List<String> allergies; // customer-declared allergies

  const UserProfile({
    required this.name,
    this.language,
    this.homeAddress,
    this.homeLat,
    this.homeLng,
    this.allergies = const [],
  });

  UserProfile copyWith({
    String? name,
    String? language,
    String? homeAddress,
    double? homeLat,
    double? homeLng,
    List<String>? allergies,
  }) {
    return UserProfile(
      name: name ?? this.name,
      language: language ?? this.language,
      homeAddress: homeAddress ?? this.homeAddress,
      homeLat: homeLat ?? this.homeLat,
      homeLng: homeLng ?? this.homeLng,
      allergies: allergies ?? this.allergies,
    );
  }
}

class AuthUser {
  final String id;
  final UserRole role;
  final UserProfile profile;

  const AuthUser({required this.id, required this.role, required this.profile});
}
