package com.budgetly.api.exception;

/**
 * Thrown when an auth feature (e.g. Google sign-in) is reached but the server has no
 * usable configuration for it, so the request cannot be processed.
 *
 * <p>Maps to HTTP 503 so clients see a distinct, actionable failure rather than the
 * generic 400 "invalid token" produced when verification is misconfigured.
 */
public class AuthNotConfiguredException extends RuntimeException {

    public AuthNotConfiguredException(String message) {
        super(message);
    }
}