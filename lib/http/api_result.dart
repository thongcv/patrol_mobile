import 'api_failure.dart';



/// Empty value for APIs that only need success/failure (logout, forgot, PUT with no body).
enum ApiUnit {
  instance,
}

sealed class ApiResult<T> {
  const ApiResult._();

  bool get isSuccess => this is ApiSuccess<T>;

  bool get isFailure => this is ApiFailed<T>;

  T? get dataOrNull => switch (this) {
        ApiSuccess<T>(:final data) => data,
        ApiFailed<T>() => null,
      };

  ApiFailure? get failureOrNull => switch (this) {
        ApiSuccess<T>() => null,
        ApiFailed<T>(:final failure) => failure,
      };

  /// Has successful payload (equivalent to [isSuccess]).
  bool get ok => isSuccess;

  /// Failure on error; `null` on success (alias [failureOrNull]).
  ApiFailure? get failure => failureOrNull;

  /// Payload on success; `null` on error (alias [dataOrNull]).
  T? get data => dataOrNull;

  factory ApiResult.success(T data) => ApiSuccess(data);

  factory ApiResult.failure(ApiFailure failure) => ApiFailed(failure);
}

final class ApiSuccess<T> extends ApiResult<T> {
  const ApiSuccess(this.data) : super._();

  @override
  final T data;
}

final class ApiFailed<T> extends ApiResult<T> {
  const ApiFailed(this.failure) : super._();

  @override
  final ApiFailure failure;
}
