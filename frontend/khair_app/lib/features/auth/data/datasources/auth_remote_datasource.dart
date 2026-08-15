import '../../../../core/network/api_client.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthResponseModel> login(String email, String password);
  Future<AuthResponseModel> register(
      String email, String password, String name);
  Future<AuthResponseModel> loginWithGoogle(
      String idToken, String preferredLanguage);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient _apiClient;

  AuthRemoteDataSourceImpl(this._apiClient);

  @override
  Future<AuthResponseModel> login(String email, String password) async {
    final response = await _apiClient.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return AuthResponseModel.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<AuthResponseModel> register(
      String email, String password, String name) async {
    final response = await _apiClient.post('/auth/register', data: {
      'email': email,
      'password': password,
      'name': name,
    });
    return AuthResponseModel.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<AuthResponseModel> loginWithGoogle(
      String idToken, String preferredLanguage) async {
    final response = await _apiClient.post('/auth/google', data: {
      'id_token': idToken,
      'preferred_language': preferredLanguage,
    });
    return AuthResponseModel.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }
}
