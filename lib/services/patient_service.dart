import '../core/api/api_client.dart';

class PatientService {
  Future<List<dynamic>> getPatients() async {
    final response = await ApiClient.dio.get('/patients');
    return List<dynamic>.from(response.data as List);
  }
}
