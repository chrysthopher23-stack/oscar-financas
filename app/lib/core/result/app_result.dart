sealed class AppResult<T> {
  const AppResult();
}

final class AppSuccess<T> extends AppResult<T> {
  const AppSuccess(this.value);
  final T value;
}

final class AppFailure<T> extends AppResult<T> {
  const AppFailure(this.code, {this.cause});
  final String code;
  final Object? cause;
}
