import 'dart:io';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'api_response.dart';
import 'patrol_dio.dart';

const merchantLogoFolder = 'images/merchants';
const avatarFolder = 'images/avatars';
const issuePhotosFolder = 'images/issues';
const patrolLogPhotosFolder = 'images/patrol-logs';

/// Metadata returned after a successful presigned PUT.
class PresignedUploadResult {
  const PresignedUploadResult({
    required this.objectKey,
    required this.contentType,
    required this.originalFileName,
    required this.folder,
  });

  final String objectKey;
  final String contentType;
  final String originalFileName;
  final String folder;
}

class PresignResponse {
  const PresignResponse({
    required this.uploadUrl,
    required this.objectKey,
    this.contentType,
    this.requiredHeaders = const {},
  });

  final String uploadUrl;
  final String objectKey;
  final String? contentType;
  final Map<String, String> requiredHeaders;
}

final Dio _presignedPutDio = Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 60),
    sendTimeout: const Duration(seconds: 120),
    validateStatus: (status) => status != null && status < 600,
  ),
);

String _fileNameFromPath(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty) return 'upload';
  final parts = trimmed.split(RegExp(r'[/\\]'));
  final name = parts.last.trim();
  return name.isNotEmpty ? name : 'upload';
}

String _guessContentType(String fileName) {
  final ext = fileName.contains('.')
      ? fileName.split('.').last.toLowerCase()
      : '';
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'heic':
      return 'image/heic';
    default:
      return 'application/octet-stream';
  }
}

Map<String, String> _coerceStringMap(dynamic value) {
  if (value is! Map) return const {};
  final out = <String, String>{};
  for (final entry in value.entries) {
    final k = entry.key?.toString().trim();
    final v = entry.value?.toString();
    if (k != null && k.isNotEmpty && v != null) {
      out[k] = v;
    }
  }
  return out;
}

/// Request a presigned PUT URL from the API.
Future<PresignResponse> requestPresignedUpload({
  required String contentType,
  String? fileName,
  String? folder,
  String presignPath = '/storage/presign',
  CancelToken? cancelToken,
}) async {
  final uri = AppConfig.resolveApiUri(presignPath);
  final res = await PatrolDio.instance.postUri<dynamic>(
    uri,
    data: {
      'contentType': contentType,
      'fileName': fileName,
      'folder': folder,
    },
    cancelToken: cancelToken,
  );

  final status = res.statusCode ?? 0;
  if (status != 200 && status != 201) {
    throw DioException(
      requestOptions: res.requestOptions,
      response: res,
      type: DioExceptionType.badResponse,
      message: 'Presign failed: $status',
    );
  }

  final presign = responseEnvelopeData(res.data);
  final uploadUrl = jsonStr(presign?['uploadUrl']);
  final objectKey = jsonStr(presign?['objectKey']);
  if (uploadUrl == null || objectKey == null) {
    throw StateError('Invalid presign response');
  }

  return PresignResponse(
    uploadUrl: uploadUrl,
    objectKey: objectKey,
    contentType: jsonStr(presign?['contentType']),
    requiredHeaders: _coerceStringMap(presign?['requiredHeaders']),
  );
}

/// Upload one local file — presign + PUT (no confirm; send [objectKey] with the business API).
Future<PresignedUploadResult> uploadViaPresignedUrl(
  String filePath, {
  String? folder,
  String? fileName,
  CancelToken? cancelToken,
  bool confirm = false,
  String? ownerType,
  Object? ownerId,
  String presignPath = '/storage/presign',
}) async {
  final path = filePath.trim();
  if (path.isEmpty) {
    throw ArgumentError('File path is required');
  }

  final resolvedFileName = fileName ?? _fileNameFromPath(path);
  final resolvedFolder = folder ?? 'uploads';
  final contentType = _guessContentType(resolvedFileName);

  final presign = await requestPresignedUpload(
    contentType: contentType,
    fileName: resolvedFileName,
    folder: resolvedFolder,
    presignPath: presignPath,
    cancelToken: cancelToken,
  );

  final file = File(path);
  final bytes = await file.readAsBytes();

  final headers = <String, dynamic>{
    ...presign.requiredHeaders,
    'Content-Type': presign.contentType ?? contentType,
  };

  final putRes = await _presignedPutDio.put<dynamic>(
    presign.uploadUrl,
    data: bytes,
    options: Options(headers: headers),
    cancelToken: cancelToken,
  );

  final putStatus = putRes.statusCode ?? 0;
  if (putStatus < 200 || putStatus >= 300) {
    throw DioException(
      requestOptions: putRes.requestOptions,
      response: putRes,
      type: DioExceptionType.badResponse,
      message: 'Storage PUT failed: $putStatus',
    );
  }

  final uploaded = PresignedUploadResult(
    objectKey: presign.objectKey,
    contentType: presign.contentType ?? contentType,
    originalFileName: resolvedFileName,
    folder: resolvedFolder,
  );

  if (confirm) {
    await confirmUploadedObject(
      objectKey: uploaded.objectKey,
      originalFileName: resolvedFileName,
      folder: resolvedFolder,
      ownerType: ownerType,
      ownerId: ownerId,
      cancelToken: cancelToken,
    );
  }

  return uploaded;
}

/// Public presign (merchant registration) — merchant logo folder only.
Future<PresignedUploadResult> uploadMerchantLogoViaPresignedUrl(
  String filePath, {
  String? fileName,
  CancelToken? cancelToken,
  bool confirm = false,
  String? ownerType,
  Object? ownerId,
}) {
  return uploadViaPresignedUrl(
    filePath,
    folder: merchantLogoFolder,
    fileName: fileName,
    cancelToken: cancelToken,
    confirm: confirm,
    ownerType: ownerType,
    ownerId: ownerId,
    presignPath: '/public/presign',
  );
}

Future<PresignedUploadResult> uploadAvatarViaPresignedUrl(
  String filePath, {
  String? fileName,
  CancelToken? cancelToken,
  bool confirm = false,
  String? ownerType,
  Object? ownerId,
}) {
  return uploadViaPresignedUrl(
    filePath,
    folder: avatarFolder,
    fileName: fileName,
    cancelToken: cancelToken,
    confirm: confirm,
    ownerType: ownerType,
    ownerId: ownerId,
  );
}

Future<List<PresignedUploadResult>> uploadIssuePhotosViaPresignedUrl(
  List<String> filePaths, {
  CancelToken? cancelToken,
  bool confirm = false,
  String? ownerType,
  Object? ownerId,
  int concurrency = 3,
  void Function(int done, int total, String filePath, PresignedUploadResult meta)?
      onProgress,
}) {
  return uploadFilesViaPresignedUrl(
    filePaths,
    folder: issuePhotosFolder,
    cancelToken: cancelToken,
    confirm: confirm,
    ownerType: ownerType,
    ownerId: ownerId,
    concurrency: concurrency,
    onProgress: onProgress,
  );
}

Future<List<PresignedUploadResult>> uploadPatrolLogPhotosViaPresignedUrl(
  List<String> filePaths, {
  CancelToken? cancelToken,
  bool confirm = false,
  String? ownerType,
  Object? ownerId,
  int concurrency = 3,
  void Function(int done, int total, String filePath, PresignedUploadResult meta)?
      onProgress,
}) {
  return uploadFilesViaPresignedUrl(
    filePaths,
    folder: patrolLogPhotosFolder,
    cancelToken: cancelToken,
    confirm: confirm,
    ownerType: ownerType,
    ownerId: ownerId,
    concurrency: concurrency,
    onProgress: onProgress,
  );
}

/// Confirm one uploaded object (usually unnecessary — prefer confirm in the business API).
Future<Map<String, dynamic>?> confirmUploadedObject({
  required String objectKey,
  String? originalFileName,
  String? folder,
  String? ownerType,
  Object? ownerId,
  CancelToken? cancelToken,
}) async {
  final uri = AppConfig.resolveApiUri('/storage/confirm');
  final res = await PatrolDio.instance.postUri<dynamic>(
    uri,
    data: {
      'objectKey': objectKey,
      'originalFileName': ?originalFileName,
      'folder': ?folder,
      'ownerType': ?ownerType,
      'ownerId': ?ownerId,
    },
    cancelToken: cancelToken,
  );

  final status = res.statusCode ?? 0;
  if (status != 200 && status != 201) {
    throw DioException(
      requestOptions: res.requestOptions,
      response: res,
      type: DioExceptionType.badResponse,
      message: 'Storage confirm failed: $status',
    );
  }

  return responseEnvelopeData(res.data);
}

/// Upload many local files — PUT only; returns `{ objectKey, ... }` metadata.
Future<List<PresignedUploadResult>> uploadFilesViaPresignedUrl(
  List<String> filePaths, {
  String? folder,
  CancelToken? cancelToken,
  bool confirm = false,
  String? ownerType,
  Object? ownerId,
  String presignPath = '/storage/presign',
  int concurrency = 3,
  void Function(int done, int total, String filePath, PresignedUploadResult meta)?
      onProgress,
}) async {
  final list = filePaths.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  if (list.isEmpty) return const [];

  final workers = concurrency.clamp(1, list.length);
  final results = List<PresignedUploadResult?>.filled(list.length, null);
  var nextIndex = 0;
  var done = 0;

  Future<void> worker() async {
    while (true) {
      final index = nextIndex;
      nextIndex += 1;
      if (index >= list.length) return;

      final path = list[index];
      final meta = await uploadViaPresignedUrl(
        path,
        folder: folder,
        fileName: _fileNameFromPath(path),
        cancelToken: cancelToken,
        confirm: confirm,
        ownerType: ownerType,
        ownerId: ownerId,
        presignPath: presignPath,
      );
      results[index] = meta;
      done += 1;
      onProgress?.call(done, list.length, path, meta);
    }
  }

  await Future.wait(List.generate(workers, (_) => worker()));
  return results.whereType<PresignedUploadResult>().toList();
}

/// Extract `objectKey` values for issue / patrol-log requests.
List<String> toObjectKeys(List<PresignedUploadResult> uploadedList) {
  return uploadedList.map((item) => item.objectKey).where((k) => k.isNotEmpty).toList();
}
