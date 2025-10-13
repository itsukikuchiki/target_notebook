sealed class Result<T> {
  const Result();
  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;
  T get require => (this as Success<T>).value;
  E? error<E extends Exception>() => this is Failure<T> ? (this as Failure<T>).exception as E : null;
}

class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

class Failure<T> extends Result<T> {
  final Exception exception;
  final StackTrace? stackTrace;
  const Failure(this.exception, [this.stackTrace]);
}

