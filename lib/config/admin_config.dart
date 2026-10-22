class AdminConfig {
  /// Default secret key required for registering or logging in as an Admin.
  static const String adminSecretKey = "HOSTELHUNT_ADMIN_2026";

  /// Validates whether the provided input key matches the admin secret key.
  static bool validateSecretKey(String inputKey) {
    return inputKey.trim() == adminSecretKey;
  }
}
