# ADR 0001: Raw Google OAuth 2.0 + Custom JWT (no Firebase)

## Status
Accepted

## Context
Budgetly needs Google Sign-In for both the Flutter app and the backend. Two hosting options were
considered:

- **Firebase Authentication**: managed identity provider — Google token verification, user
  management, and token lifecycle are handled for us, at the cost of a Firebase dependency and
  a second vendor/API surface.
- **Raw Google OAuth 2.0 + custom JWT**: the client obtains a Google ID token; the backend
  verifies it directly with Google and mints its own application JWT.

The application already owns its user store (`UserDocument`) and wants to keep auth lean and
self-hosted. The decision is to **not** adopt Firebase and instead verify Google ID tokens
ourselves, taking responsibility for the token lifecycle.

## Decision

1. **Client**: the Flutter app signs in with `google_sign_in` (`^7.2.0`) and sends the resulting
   Google ID token to `POST /api/v1/auth/google` (`GoogleSignInRequest.idToken`).

2. **Verification**: `security/GoogleTokenVerifier` (built on `google-api-client` 2.9.2,
   `GoogleIdTokenVerifier`) verifies the ID token against the configured audience
   (`google.client-id`, env `GOOGLE_CLIENT_ID`). `GoogleAuthConfigValidator` /
   `GoogleTokenVerifier.isConfigured()` fail fast when the client ID is missing or a placeholder,
   surfacing a 503 `AuthNotConfiguredException` instead of an opaque invalid-token 400.

3. **User resolution**: `AuthService.googleSignIn` extracts the Google payload
   (`sub`, `email`, `name`, `picture`), find-or-creates the `UserDocument` keyed by the Google
   `sub`, and refreshes the profile fields.

4. **App tokens**: `security/JwtTokenProvider` (JJWT `io.jsonwebtoken` 0.12.6) mints HS256 JWTs
   signed with `jwt.secret` (env `JWT_SECRET`): an access token (default 24h) and a refresh token
   (default 7d), each carrying a `type` claim. `POST /api/v1/auth/refresh` exchanges the refresh
   token for a new pair.

5. **Request auth**: `security/JwtAuthFilter` (a Spring Security `OncePerRequestFilter`) validates
   the `Authorization: Bearer <jwt>` on every request and populates the `SecurityContext` with the
   user id. The Flutter Dio client (`app/lib/data/remote/api_client.dart`) attaches the bearer
   token and retries once on 401 by refreshing.

## Consequences
- **No Firebase dependency** — no Firebase Admin SDK, no vendor lock-in; auth runs entirely on our
  own stack.
- **Full control over token lifecycle** — expiration, refresh, and (future) revocation are ours to
  tune. The trade-off is that token security is also our responsibility: `JWT_SECRET` must be a
  strong, rotated secret outside development (the `application.yml` default is a dev-only value),
  and `GOOGLE_CLIENT_ID` must be a real `*.apps.googleusercontent.com` web client ID in every
  non-dev environment.
- **Client-side refresh logic lives in the app** — the Dio interceptor owns the refresh-on-401
  flow, so access-token expiry is transparent to screens.
- **Two JWT/verification libraries to keep patched** — `google-api-client` and JJWT are part of the
  backend attack surface and are updated alongside the dependency upgrade in ADR-0004.