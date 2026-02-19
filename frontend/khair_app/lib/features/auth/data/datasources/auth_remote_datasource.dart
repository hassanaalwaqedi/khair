import '../../../../core/network/api_client.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthResponseModel> login(String email, String password);
  Future<AuthResponseModel> register(String email, String password, String name);
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
    return AuthResponseModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<AuthResponseModel> register(String email, String password, String name) async {
    final response = await _apiClient.post('/auth/register', data: {
      'email': email,
      'password': password,
      'name': name,
    });
    return AuthResponseModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }
}
