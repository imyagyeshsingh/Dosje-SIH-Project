class AppException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  AppException(this.message, {this.statusCode, this.details});

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  NetworkException([String message = 'Network connection error'])
    : super(message);
}

class UnauthorizedException extends AppException {
  UnauthorizedException([String message = 'Session expired or unauthorized'])
    : super(message, statusCode: 401);
}

class ForbiddenException extends AppException {
  ForbiddenException([String message = 'Access denied'])
    : super(message, statusCode: 403);
}

class NotFoundException extends AppException {
  NotFoundException([String message = 'Resource not found'])
    : super(message, statusCode: 404);
}

class BadRequestException extends AppException {
  BadRequestException([String message = 'Bad request', dynamic details])
      : super(message, statusCode: 400, details: details);
}

class ConflictException extends AppException {
  ConflictException([String message = 'Resource conflict', dynamic details])
      : super(message, statusCode: 409, details: details);
}

class ValidationException extends AppException {
  ValidationException([String message = 'Validation error', dynamic details])
      : super(message, statusCode: 422, details: details);
}

class ServerException extends AppException {
  ServerException([String message = 'Internal server error occurred'])
      : super(message, statusCode: 500);
}

