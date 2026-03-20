import 'dart:async';
import 'package:dio/dio.dart';
import 'auth_service.dart';

class ApiService {
  final Dio _dio = Dio();
  final AuthService _authService = AuthService();
  Timer? _keepAliveTimer;
  
  // Base URL for the FastAPI backend (Render URL or localhost)
  // Live Render URL
  final String baseUrl = 'http://192.168.0.102:8000';

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

    // Start keep-alive ping
    startKeepAlivePing();
  }

  // System Endpoints
  Future<Response> healthCheck() => _dio.get('/health');

  void startKeepAlivePing() {
    // Ping every 10 minutes to prevent Render from sleeping
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(minutes: 10), (timer) async {
      try {
        await healthCheck();
        print('Keep-alive ping sent to $baseUrl/health');
      } catch (e) {
        print('Keep-alive ping failed: $e');
      }
    });
  }

  void stopKeepAlivePing() {
    _keepAliveTimer?.cancel();
  }

  // Auth Endpoints
  Future<Response> register(Map<String, dynamic> data) => _dio.post('/auth/register', data: data);
  Future<Response> login(Map<String, dynamic> data) => _dio.post('/auth/login', data: data);
  Future<Response> verifyMfa(Map<String, dynamic> data) => _dio.post('/auth/mfa/verify', data: data);
  Future<Response> getEmployees() => _dio.get('/auth/employees');

  // Tasks Endpoints
  Future<Response> getTasks() => _dio.get('/tasks');
  Future<Response> getAssignedTasks(String userId) => _dio.get('/tasks/assigned', queryParameters: {'user_id': userId});
  Future<Response> createTask(Map<String, dynamic> data) => _dio.post('/tasks/create', data: data);
  Future<Response> updateTask(String id, Map<String, dynamic> data) => _dio.patch('/tasks/$id/status', data: data);

  // Files Endpoints
  Future<Response> sendFile(Map<String, dynamic> data) => _dio.post('/files/send', data: data);
  Future<Response> getReceivedFiles(String userId) => _dio.get('/files/received', queryParameters: {'receiver_id': userId});
  Future<Response> confirmFile(String id, String userId) => _dio.post('/files/$id/confirm', queryParameters: {'receiver_id': userId});
  Future<Response> decryptFile(String id, Map<String, dynamic> data) => _dio.post('/files/$id/decrypt', data: data);

  // Messages Endpoints
  Future<Response> getMessages(String userId) => _dio.get('/messages/$userId');
  Future<Response> sendMessage(Map<String, dynamic> data) => _dio.post('/messages/send', data: data);

  // Audit Logs Endpoint
  Future<Response> getAuditLogs() => _dio.get('/audit/logs');
}
