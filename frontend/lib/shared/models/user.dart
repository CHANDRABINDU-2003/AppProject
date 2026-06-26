class AppUser {
  final int id;
  final String name;
  final String email;
  final String role; // farmer | seller | analyst
  final int? regionId;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.regionId,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j["id"],
        name: j["name"],
        email: j["email"],
        role: j["role"],
        regionId: j["region_id"],
      );
}
