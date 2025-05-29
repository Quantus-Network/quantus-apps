import 'package:http/http.dart' as http;

class PrometheusService {
  static Future<double?> fetchHashrate() async {
    try {
      final res = await http.get(Uri.parse('http://127.0.0.1:9616/metrics')).timeout(const Duration(seconds: 1));
      final line = res.body.split('\n').firstWhere((l) => l.startsWith('pow_hashrate'));
      return double.parse(line.split(' ').last);
    } catch (_) {
      return null;
    }
  }
}
