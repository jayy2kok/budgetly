package com.budgetly.api.service;

import com.budgetly.api.document.UserDocument;
import com.budgetly.api.exception.ResourceNotFoundException;
import com.budgetly.api.generated.model.*;
import com.budgetly.api.repository.UserRepository;
import com.budgetly.api.security.GoogleTokenVerifier;
import com.budgetly.api.security.JwtTokenProvider;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.time.ZoneOffset;

@Slf4j
@Service
@RequiredArgsConstructor
public class AuthService {

    private final GoogleTokenVerifier googleTokenVerifier;
    private final JwtTokenProvider jwtTokenProvider;
    private final UserRepository userRepository;

    public AuthResponse googleSignIn(GoogleSignInRequest request) {
        GoogleIdToken.Payload payload = googleTokenVerifier.verify(request.getIdToken());
        if (payload == null) {
            throw new IllegalArgumentException("Invalid Google ID token");
        }

        String googleId = payload.getSubject();
        String email = payload.getEmail();
        String displayName = (String) payload.get("name");
        String avatarUrl = (String) payload.get("picture");

        // Find or create user
        UserDocument user = userRepository.findByGoogleId(googleId)
                .orElseGet(() -> {
                    UserDocument newUser = UserDocument.builder()
                            .googleId(googleId)
                            .email(email)
                            .displayName(displayName != null ? displayName : email)
                            .avatarUrl(avatarUrl)
                            .build();
                    return userRepository.save(newUser);
                });

        // Update profile info
        boolean dirty = false;
        if (displayName != null && !displayName.equals(user.getDisplayName())) {
            user.setDisplayName(displayName);
            dirty = true;
        }
        if (avatarUrl != null && !avatarUrl.equals(user.getAvatarUrl())) {
            user.setAvatarUrl(avatarUrl);
            dirty = true;
        }
        if (dirty) userRepository.save(user);

        String accessToken = jwtTokenProvider.generateAccessToken(user.getId());
        String refreshToken = jwtTokenProvider.generateRefreshToken(user.getId());

        AuthResponse response = new AuthResponse();
        response.setAccessToken(accessToken);
        response.setRefreshToken(refreshToken);
        response.setExpiresIn((int) (jwtTokenProvider.getExpirationMs() / 1000));
        response.setUser(toUserDto(user));
        return response;
    }

    public AuthResponse refreshToken(RefreshTokenRequest request) {
        String refreshToken = request.getRefreshToken();
        if (!jwtTokenProvider.validateToken(refreshToken)) {
            throw new IllegalArgumentException("Invalid or expired refresh token");
        }
        String userId = jwtTokenProvider.getUserIdFromToken(refreshToken);
        UserDocument user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User", userId));

        String newAccessToken = jwtTokenProvider.generateAccessToken(userId);
        String newRefreshToken = jwtTokenProvider.generateRefreshToken(userId);

        AuthResponse response = new AuthResponse();
        response.setAccessToken(newAccessToken);
        response.setRefreshToken(newRefreshToken);
        response.setExpiresIn((int) (jwtTokenProvider.getExpirationMs() / 1000));
        response.setUser(toUserDto(user));
        return response;
    }

    public User getCurrentUser(String userId) {
        UserDocument user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User", userId));
        return toUserDto(user);
    }

    public static User toUserDto(UserDocument doc) {
        User dto = new User();
        dto.setId(doc.getId());
        dto.setGoogleId(doc.getGoogleId());
        dto.setDisplayName(doc.getDisplayName());
        dto.setEmail(doc.getEmail());
        // avatarUrl may be URI or String depending on generated model
        if (doc.getAvatarUrl() != null) {
            try {
                dto.setAvatarUrl(URI.create(doc.getAvatarUrl()));
            } catch (Exception e) {
                // If generated model has String type, this won't compile — handled at generate time
                log.debug("avatarUrl not set as URI: {}", e.getMessage());
            }
        }
        if (doc.getCreatedAt() != null) {
            dto.setCreatedAt(doc.getCreatedAt().atOffset(ZoneOffset.UTC));
        }
        return dto;
    }

    public UserDocument getUserDocument(String userId) {
        return userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User", userId));
    }
}
