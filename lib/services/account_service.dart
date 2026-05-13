import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../http/api_request_headers.dart';
import '../http/api_response.dart';
import '../models/account_me.dart';

enum AccountMeFailure { configMissing, unauthorized, network, badResponse }

class AccountMeResult {
  AccountMeResult._({this.data, this.failure});

  final AccountMeDto? data;
  final AccountMeFailure? failure;

  bool get ok => data != null;

  factory AccountMeResult.success(AccountMeDto data) =>
      AccountMeResult._(data: data);

  factory AccountMeResult.failure(AccountMeFailure f) =>
      AccountMeResult._(failure: f);
}

class AccountService {
  AccountService._();
  static final AccountService instance = AccountService._();

  Future<AccountMeResult> fetchMe() async {
    final base = AppConfig.effectiveBaseUrl;
    if (base.isEmpty) {
      return AccountMeResult.failure(AccountMeFailure.configMissing);
    }

    final uri = Uri.parse('$base/api/accounts/me');
    try {
      final res = await http
          .get(
            uri,
            headers: await ApiRequestHeaders.build(jsonBody: false),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 401 || res.statusCode == 403) {
        return AccountMeResult.failure(AccountMeFailure.unauthorized);
      }
      if (res.statusCode != 200) {
        return AccountMeResult.failure(AccountMeFailure.badResponse);
      }

      final map = parseApiResponseData(res.body);
      if (map == null) {
        return AccountMeResult.failure(AccountMeFailure.badResponse);
      }

      try {
        final me = AccountMeDto.fromJson(map);
        return AccountMeResult.success(me);
      } catch (_) {
        return AccountMeResult.failure(AccountMeFailure.badResponse);
      }
    } catch (_) {
      return AccountMeResult.failure(AccountMeFailure.network);
    }
  }
}
