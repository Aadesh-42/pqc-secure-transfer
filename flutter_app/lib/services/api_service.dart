import 'package:dio/dio.dart';
import 'auth_service.dart';

class ApiService {
  final Dio _dio = Dio();
  final AuthService _authService = AuthService();
  
  // Base URL for the FastAPI backend (Render URL or localhost)
  // Live Render URL
  final String baseUrl = 'https://pqc-secure-transfer.onrender.com';

  ApiService() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);
    
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _authService.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            // Handle unauthorized globally (e.g., token expired)
            await _authService.logout();
            // Need a way to navigate to login without context here. 
            // In a real app we might emit a stream event.
          }
          return handler.next(e);
        }
      )
    );
  }

  // Auth Endpoints
  Future<Response> register(Map<String, динамический> data) => _dio.post('/auth/register', data: data);
  Future<Response> login(Map<String, динамический> data) => _dio.post('/auth/login', data: data);
  Future<Response> verifyMfa(Map<String, динамический> data) => _dio.post('/auth/mfa/verify', data: data);

  // Tasks Endpoints
  Future<Response> getTasks() => _dio.get('/tasks');
  Future<Response> createTask(Map<String, динамический> data) => _dio.post('/tasks/create', data: data);
  Future<Response> updateTask(String id, Map<String, динамический> data) => _dio.patch('/tasks/$id/status', data: data);

  // Files Endpoints
  Future<Response> sendFile(Map<String, динамический> data) => _dio.post('/files/send', data: data);
  Future<Response> confirmFile(String id) => _dio.post('/files/$id/confirm');
  Future<Response> decryptFile(String id, Map<String, динамический> data) => _dio.post('/files/$id/decrypt', data: data);

  // Messages Endpoints
  Future<Response> getMessages(String userId) => _dio.get('/messages/$userId');
  Future<Response> sendMessage(Map<String, динамический> data) => _dio.post('/messages/send', data: data);

  // Audit Logs Endpoint
  Future<Response> getAuditLogs() => _dio.get('/audit/logs');
}
