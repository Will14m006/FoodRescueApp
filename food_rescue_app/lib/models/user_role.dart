/// Peran pengguna — harus sama persis dengan `UserRole` di backend.
enum UserRole {
  buyer,
  merchant,
  admin;

  static UserRole fromName(String? name) {
    switch (name) {
      case 'merchant':
        return UserRole.merchant;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.buyer;
    }
  }

  String get label {
    switch (this) {
      case UserRole.buyer:
        return 'Pembeli';
      case UserRole.merchant:
        return 'Merchant';
      case UserRole.admin:
        return 'Admin';
    }
  }
}
