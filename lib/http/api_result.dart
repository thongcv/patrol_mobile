import 'api_failure.dart';



/// Giá trị “rỗng” cho API chỉ cần biết thành công / thất bại (logout, forgot, PUT không body).
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

  /// Có payload thành công (tương đương [isSuccess]).
  bool get ok => isSuccess;

  /// Lỗi khi thất bại; `null` khi thành công (alias [failureOrNull]).
  ApiFailure? get failure => failureOrNull;

  /// Payload khi thành công; `null` khi lỗi (alias [dataOrNull]).
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
