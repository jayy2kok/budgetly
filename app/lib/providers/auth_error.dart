/// Maps sign-in failures to short, user-facing messages (issue #23).
///
/// Raw exceptions (Dio internals, URLs, stacks) are logged via [debugPrint] —
/// never shown — so the login banner stays compact and actionable.
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

enum AuthErrorKind { network, rejected, server, unknown }

/// Classifies [error] so it can be mapped to a short message.
AuthErrorKind authErrorKind(Object error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AuthErrorKind.network;
      case DioExceptionType.badCertificate:
        return AuthErrorKind.server;
      case DioExceptionType.badResponse:
        if (status != null && status >= 500) return AuthErrorKind.server;
        if (status != null && status >= 400) return AuthErrorKind.rejected;
        return AuthErrorKind.unknown;
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return AuthErrorKind.unknown;
    }
  }
  if (error is SocketException) return AuthErrorKind.network;
  return AuthErrorKind.unknown;
}

/// The short, user-facing message for a failed sign-in.
///
/// [debugPrint] is reserved for the caller to log the raw exception.
String authErrorMessage(Object error) {
  switch (authErrorKind(error)) {
    case AuthErrorKind.network:
      return "Can't reach Budgetly. Check your connection.";
    case AuthErrorKind.rejected:
      return 'Google sign-in was rejected. Please try again.';
    case AuthErrorKind.server:
      return 'Budgetly is having trouble. Try again in a moment.';
    case AuthErrorKind.unknown:
      return "Couldn't sign in right now. Please try again.";
  }
}