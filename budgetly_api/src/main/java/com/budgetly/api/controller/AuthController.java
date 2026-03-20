package com.budgetly.api.controller;

import com.budgetly.api.generated.controller.AuthApi;
import com.budgetly.api.generated.model.*;
import com.budgetly.api.service.AuthService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class AuthController implements AuthApi {

    private final AuthService authService;

    @Override
    public ResponseEntity<AuthResponse> googleSignIn(GoogleSignInRequest googleSignInRequest) {
        return ResponseEntity.ok(authService.googleSignIn(googleSignInRequest));
    }

    @Override
    public ResponseEntity<AuthResponse> refreshToken(RefreshTokenRequest refreshTokenRequest) {
        return ResponseEntity.ok(authService.refreshToken(refreshTokenRequest));
    }

    @Override
    public ResponseEntity<User> getCurrentUser() {
        String userId = ControllerUtils.getCurrentUserId();
        return ResponseEntity.ok(authService.getCurrentUser(userId));
    }
}
