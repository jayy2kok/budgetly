package com.budgetly.api.push;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyFactory;
import java.security.PrivateKey;
import java.security.Signature;
import java.security.spec.PKCS8EncodedKeySpec;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Firebase Cloud Messaging HTTP v1 transport.
 *
 * <p>Kept dependency-free on purpose: the OAuth2 service-account assertion is
 * minted and exchanged with the JDK HTTP client, so the API does not pull a
 * second Google auth stack into the build. Enabled with
 * {@code push.provider=fcm} plus {@code push.fcm.project-id} and
 * {@code push.fcm.service-account-file}.
 */
@Slf4j
@Service
@RequiredArgsConstructor
@ConditionalOnProperty(name = "push.provider", havingValue = "fcm")
public class FcmPushNotificationService implements PushNotificationService {

    private static final String FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
    private static final String JWT_BEARER_GRANT = "urn:ietf:params:oauth:grant-type:jwt-bearer";

    private final ObjectMapper objectMapper;

    @Value("${push.fcm.project-id:}")
    private String projectId;

    @Value("${push.fcm.service-account-file:}")
    private String serviceAccountFile;

    @Value("${push.fcm.base-url:https://fcm.googleapis.com}")
    private String baseUrl;

    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(5))
            .build();

    private JsonNode credentials;
    private PrivateKey privateKey;
    private String cachedAccessToken;
    private Instant accessTokenExpiresAt = Instant.EPOCH;

    @PostConstruct
    void loadCredentials() {
        if (projectId == null || projectId.isBlank()) {
            log.warn("push.provider=fcm but push.fcm.project-id is empty — pushes will be skipped");
            return;
        }
        if (serviceAccountFile == null || serviceAccountFile.isBlank()) {
            log.warn("push.provider=fcm but push.fcm.service-account-file is empty — pushes will be skipped");
            return;
        }
        try {
            String json = Files.readString(Path.of(serviceAccountFile), StandardCharsets.UTF_8);
            credentials = objectMapper.readTree(json);
            String pem = credentials.path("private_key").asText();
            privateKey = parsePrivateKey(pem);
            log.info("FCM push enabled for project {}", projectId);
        } catch (Exception e) {
            log.warn("Could not load FCM service-account credentials from {}: {} — pushes will be skipped",
                    serviceAccountFile, e.getMessage());
            credentials = null;
            privateKey = null;
        }
    }

    @Override
    public void send(List<PushMessage> messages) {
        if (messages == null || messages.isEmpty() || credentials == null || privateKey == null) {
            return;
        }
        for (PushMessage message : messages) {
            try {
                sendOne(message);
            } catch (Exception e) {
                // An unregistered/invalid token must not break the remaining fan-out.
                log.warn("FCM send failed for {}: {}", LoggingPushNotificationService.mask(message.token()),
                        e.getMessage());
            }
        }
    }

    private void sendOne(PushMessage message) throws Exception {
        Map<String, Object> android = new LinkedHashMap<>();
        android.put("priority", "high");

        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("token", message.token());
        payload.put("notification", Map.of("title", message.title(), "body", message.body()));
        payload.put("data", message.data());
        payload.put("android", android);

        String body = objectMapper.writeValueAsString(Map.of("message", payload));

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(baseUrl + "/v1/projects/" + projectId + "/messages:send"))
                .timeout(Duration.ofSeconds(10))
                .header("Authorization", "Bearer " + accessToken())
                .header("Content-Type", "application/json; charset=utf-8")
                .POST(HttpRequest.BodyPublishers.ofString(body, StandardCharsets.UTF_8))
                .build();

        HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
        if (response.statusCode() < 200 || response.statusCode() >= 300) {
            throw new IllegalStateException("HTTP " + response.statusCode() + ": " + response.body());
        }
    }

    /** Mints (and caches) the OAuth2 access token from the service account. */
    private synchronized String accessToken() throws Exception {
        if (cachedAccessToken != null && Instant.now().isBefore(accessTokenExpiresAt.minusSeconds(60))) {
            return cachedAccessToken;
        }

        String tokenUri = credentials.path("token_uri").asText("https://oauth2.googleapis.com/token");
        long issuedAt = Instant.now().getEpochSecond();
        String assertion = buildAssertion(credentials.path("client_email").asText(), tokenUri, issuedAt);

        String form = "grant_type=" + URLEncoder.encode(JWT_BEARER_GRANT, StandardCharsets.UTF_8)
                + "&assertion=" + URLEncoder.encode(assertion, StandardCharsets.UTF_8);

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(tokenUri))
                .timeout(Duration.ofSeconds(10))
                .header("Content-Type", "application/x-www-form-urlencoded")
                .POST(HttpRequest.BodyPublishers.ofString(form, StandardCharsets.UTF_8))
                .build();

        HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
        if (response.statusCode() < 200 || response.statusCode() >= 300) {
            throw new IllegalStateException("OAuth token exchange failed: HTTP " + response.statusCode());
        }

        JsonNode tokenResponse = objectMapper.readTree(response.body());
        cachedAccessToken = tokenResponse.path("access_token").asText();
        long expiresIn = tokenResponse.path("expires_in").asLong(3600);
        accessTokenExpiresAt = Instant.now().plusSeconds(expiresIn);
        return cachedAccessToken;
    }

    private String buildAssertion(String clientEmail, String tokenUri, long issuedAt) throws Exception {
        Base64.Encoder base64 = Base64.getUrlEncoder().withoutPadding();

        Map<String, Object> header = new LinkedHashMap<>();
        header.put("alg", "RS256");
        header.put("typ", "JWT");

        Map<String, Object> claims = new LinkedHashMap<>();
        claims.put("iss", clientEmail);
        claims.put("scope", FCM_SCOPE);
        claims.put("aud", tokenUri);
        claims.put("iat", issuedAt);
        claims.put("exp", issuedAt + 3600);

        String unsigned = base64.encodeToString(objectMapper.writeValueAsBytes(header))
                + "." + base64.encodeToString(objectMapper.writeValueAsBytes(claims));

        Signature signature = Signature.getInstance("SHA256withRSA");
        signature.initSign(privateKey);
        signature.update(unsigned.getBytes(StandardCharsets.UTF_8));

        return unsigned + "." + base64.encodeToString(signature.sign());
    }

    private static PrivateKey parsePrivateKey(String pem) throws Exception {
        String cleaned = pem
                .replace("-----BEGIN PRIVATE KEY-----", "")
                .replace("-----END PRIVATE KEY-----", "")
                .replaceAll("\\s", "");
        byte[] der = Base64.getDecoder().decode(cleaned);
        return KeyFactory.getInstance("RSA").generatePrivate(new PKCS8EncodedKeySpec(der));
    }
}
