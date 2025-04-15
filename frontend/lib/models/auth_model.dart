class LoginResponse {
  final int id;
  final String nickname;
  final String? token; // Może być dodane w przyszłości dla JWT

  LoginResponse({
    required this.id,
    required this.nickname,
    this.token,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      id: json['id'] as int,
      nickname: json['nickname'] as String,
      token: json['token'] as String?,
    );
  }
}