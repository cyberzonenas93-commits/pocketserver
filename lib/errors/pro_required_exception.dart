/// Thrown when a Pro-only feature is used without an active Pro subscription.
class ProRequiredException implements Exception {
  ProRequiredException([this.message = 'Pro subscription required']);
  final String message;
  @override
  String toString() => 'ProRequiredException: $message';
}
