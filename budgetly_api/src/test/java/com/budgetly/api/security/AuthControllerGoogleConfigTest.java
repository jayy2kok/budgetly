package com.budgetly.api.security;

import com.budgetly.api.exception.AuthNotConfiguredException;
import com.budgetly.api.exception.GlobalExceptionHandler;
import com.budgetly.api.generated.model.AuthResponse;
import com.budgetly.api.generated.model.GoogleSignInRequest;
import com.budgetly.api.service.AuthService;
import com.budgetly.api.controller.AuthController;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Regression for issue #24: when Google sign-in is not configured, the API must
 * return an actionable 503 rather than the generic 400 "invalid token" that made
 * the failure look like a bad client request.
 */
@ExtendWith(MockitoExtension.class)
class AuthControllerGoogleConfigTest {

    @Mock
    private AuthService authService;

    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        AuthController controller = new AuthController(authService);
        mockMvc = MockMvcBuilders.standaloneSetup(controller)
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();
    }

    @Test
    void googleSignIn_unconfiguredServer_returns503() throws Exception {
        when(authService.googleSignIn(any(GoogleSignInRequest.class)))
                .thenThrow(new AuthNotConfiguredException(
                        "Google sign-in is not configured on this server; set GOOGLE_CLIENT_ID."));

        mockMvc.perform(post("/api/v1/auth/google")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"idToken\":\"some-token\"}"))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.status").value(503))
                .andExpect(jsonPath("$.message").value(
                        "Google sign-in is not configured on this server; set GOOGLE_CLIENT_ID."));
    }

    @Test
    void googleSignIn_validToken_returns200() throws Exception {
        when(authService.googleSignIn(any(GoogleSignInRequest.class)))
                .thenReturn(new AuthResponse().accessToken("access").refreshToken("refresh").expiresIn(3600));

        mockMvc.perform(post("/api/v1/auth/google")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"idToken\":\"some-token\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").value("access"));
    }
}