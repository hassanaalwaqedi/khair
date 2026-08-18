import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final eventId = 'b203ae3b-47fd-4e09-b12b-8f9aa7fdd602';
  final response = await http.get(Uri.parse('https://api.khair.it.com/api/v1/events/$eventId'));
  
  print('Status code: ${response.statusCode}');
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    print(jsonEncode(data));
  } else {
    print('Error: ${response.body}');
  }
}
