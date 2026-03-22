import 'dart:async';
import 'package:dio/dio.dart';
import 'auth_service.dart';

class ApiService {
  final Dio _dio = Dio();
  final AuthService _authService = AuthService();
  Timer? _keepAliveTimer;
  
  // Base URL for the FastAPI backend (Render URL or localhost)
  // Live Render URL
  final String baseUrl = 'https://pqc-secure-transfer.onrender.com';

  ApiService() {
    print("API SERVICE INITIALIZED WITH BASEURL: $baseUrl");
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 15);
    
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _authService.getToken();
          print("DEBUG [API Request]: ${options.method} ${options.path}");
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
            print("DEBUG [API Request]: Token attached (starts with ${token.substring(0, 10)}...)");
          } else {
            print("DEBUG [API Request]: NO TOKEN FOUND");
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          print("DEBUG [API Response]: ${response.statusCode} from ${response.requestOptions.path}");
          return handler.next(response);
        },
        onError: (DioException e, handler) async {
          print("DEBUG [API Error]: ${e.response?.statusCode} ${e.message}");
          if (e.response?.statusCode == 401) {
            await _authService.logout();
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
  Future<Response> getAdmins() => _dio.get('/auth/admins');

  // Tasks Endpoints
  Future<Response> getTasks() => _dio.get('/tasks');
  Future<Response> getAssignedTasks(String userId) => _dio.get('/tasks/assigned', queryParameters: {'user_id': userId});
  Future<Response> createTask(Map<String, dynamic> data) => _dio.post('/tasks/create', data: data);
  Future<Response> updateTask(String id, Map<String, dynamic> data) => _dio.patch('/tasks/$id/status', data: data);

  // PQC/Files Endpoints
  Future<Response> getUserPublicKey(String userId) => _dio.get('/auth/$userId/public_key');
  Future<Response> encryptFile(Map<String, dynamic> data) => _dio.post('/files/encrypt', data: data);
  Future<Response> signFile(Map<String, dynamic> data) => _dio.post('/files/sign', data: data);
  Future<Response> sendFile(Map<String, dynamic> data) => _dio.post('/files/send', data: data);
  Future<Response> getReceivedFiles() => _dio.get('/files/received');
  Future<Response> confirmFile(String id) => _dio.post('/files/$id/confirm');
  Future<Response> decryptFile(String id, Map<String, dynamic> data) => _dio.post('/files/$id/decrypt', data: data);
  Future<Response> regenerateKeys() => _dio.get('/auth/regenerate_keys');

  // Messages Endpoints
  Future<Response> getMessages(String otherUserId) => _dio.get('/messages/$otherUserId');
  Future<Response> sendMessage(Map<String, dynamic> data) => _dio.post('/messages/send', data: data);

  // Audit Logs Endpoint
  Future<Response> getAuditLogs() => _dio.get('/audit/logs');

  // User Helpers
  Future<String?> getUserId() => _authService.getUserId();
  Future<String?> getUserEmail() => _authService.getEmail();
}
