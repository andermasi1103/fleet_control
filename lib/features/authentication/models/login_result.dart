import '../../../shared/models/user_model.dart';

class LoginResult {
  const LoginResult({
    required this.isSuccess,
    this.message,
    this.user,
  });

  final bool isSuccess;
  final String? message;
  final UserModel? user;
}
