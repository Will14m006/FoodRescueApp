import '../models/user_model.dart';

class AuthService {
  // Simulasi proses login (dummy)
  UserModel login(String email, String password) {
    return UserModel(id: '1', name: 'William', email: email);
  }
}