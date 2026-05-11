import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:workmanager/workmanager.dart';

const _taskName = 'haramainku_upload';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == _taskName) {
      return _executeUpload(inputData!);
    }
    return false;
  });
}

Future<bool> _executeUpload(Map<String, dynamic> data) async {
  final filePath = data['filePath'] as String;
  final fileName = data['fileName'] as String;
  final sessionId = data['sessionId'] as String;
  final token = data['token'] as String;
  final mode = data['mode'] as String; // 'r2' or 'direct'
  final presignedUrl = data['presignedUrl'] as String?;
  final r2Key = data['r2Key'] as String?;
  final baseUrl = data['baseUrl'] as String;
  final chunkSize = data['chunkSize'] as int;
  final totalChunks = data['totalChunks'] as int;

  try {
    final file = File(filePath);
    if (!await file.exists()) return false;

    if (mode == 'r2' && presignedUrl != null) {
      // R2 streaming upload
      final fileSize = await file.length();
      final request = await HttpClient().putUrl(Uri.parse(presignedUrl));
      request.headers.set('Content-Type', 'application/octet-stream');
      request.headers.set('Content-Length', fileSize.toString());
      final fileStream = file.openRead();
      await request.addStream(fileStream);
      final response = await request.close();
      if (response.statusCode != 200) return false;
    } else {
      // Direct chunked upload
      for (int i = 0; i < totalChunks; i++) {
        final raf = await file.open(mode: FileMode.read);
        final start = i * chunkSize;
        final fileSize = await file.length();
        final length = (start + chunkSize > fileSize) ? (fileSize - start) : chunkSize;
        await raf.setPosition(start);
        final bytes = await raf.read(length);
        await raf.close();

        bool sent = false;
        for (int retry = 0; retry < 3 && !sent; retry++) {
          try {
            final client = HttpClient();
            final request = await client.postUrl(Uri.parse('$baseUrl/api/upload/chunk'));
            request.headers.set('Authorization', 'Bearer $token');
            final boundary = 'boundary_${DateTime.now().millisecondsSinceEpoch}';
            request.headers.set('Content-Type', 'multipart/form-data; boundary=$boundary');

            final body = <int>[];
            void write(String s) => body.addAll(utf8.encode(s));

            write('--$boundary\r\n');
            write('Content-Disposition: form-data; name="sessionId"\r\n\r\n');
            write('$sessionId\r\n');
            write('--$boundary\r\n');
            write('Content-Disposition: form-data; name="chunkIndex"\r\n\r\n');
            write('$i\r\n');
            write('--$boundary\r\n');
            write('Content-Disposition: form-data; name="file"; filename="chunk"\r\n');
            write('Content-Type: application/octet-stream\r\n\r\n');
            body.addAll(bytes);
            write('\r\n--$boundary--\r\n');

            request.contentLength = body.length;
            request.add(body);
            final response = await request.close().timeout(const Duration(seconds: 120));
            await response.drain();
            if (response.statusCode == 200) sent = true;
          } catch (_) {
            if (retry >= 2) rethrow;
            await Future.delayed(Duration(seconds: (retry + 1) * 2));
          }
        }
      }
    }

    // Complete upload via GraphQL HTTP
    final completeQuery = mode == 'r2'
        ? {'query': 'mutation CompleteR2Upload($sessionId: ID!, $r2Key: String!) { completeUpload(sessionId: $sessionId, r2Key: $r2Key) { id } }', 'variables': {'sessionId': sessionId, 'r2Key': r2Key}}
        : {'query': 'mutation CompleteUpload($sessionId: ID!) { completeUpload(sessionId: $sessionId) { id } }', 'variables': {'sessionId': sessionId}};

    final gqlClient = HttpClient();
    final gqlReq = await gqlClient.postUrl(Uri.parse('$baseUrl/api/graphql'));
    gqlReq.headers.set('Content-Type', 'application/json');
    gqlReq.headers.set('Authorization', 'Bearer $token');
    gqlReq.write(jsonEncode(completeQuery));
    final gqlRes = await gqlReq.close().timeout(const Duration(seconds: 30));
    await gqlRes.drain();
    gqlClient.close();

    return gqlRes.statusCode == 200;
  } catch (_) {
    return false;
  }
}

/// Register a background upload task. Called from UI when upload starts.
void registerBackgroundUpload({
  required String filePath,
  required String fileName,
  required String sessionId,
  required String token,
  required String mode,
  String? presignedUrl,
  String? r2Key,
  required String baseUrl,
  required int chunkSize,
  required int totalChunks,
}) {
  Workmanager().registerOneOffTask(_taskName, _taskName,
    inputData: {
      'filePath': filePath,
      'fileName': fileName,
      'sessionId': sessionId,
      'token': token,
      'mode': mode,
      'presignedUrl': presignedUrl ?? '',
      'r2Key': r2Key ?? '',
      'baseUrl': baseUrl,
      'chunkSize': chunkSize,
      'totalChunks': totalChunks,
    },
    constraints: Constraints(networkType: NetworkType.connected),
  );
}
