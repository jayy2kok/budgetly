package com.budgetly.api.document;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;

/**
 * A push-notification registration token owned by one user.
 *
 * <p>Tokens are unique per provider registration: re-registering the same
 * token moves it to the calling user (a device handed to another account) and
 * refreshes {@code updatedAt} instead of inserting a duplicate.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "device_tokens")
public class DeviceTokenDocument {

    @Id
    private String id;

    @Indexed
    private String userId;

    @Indexed(unique = true)
    private String token;

    /** ANDROID | IOS | WEB */
    private String platform;

    private String deviceId;

    @Builder.Default
    private Instant createdAt = Instant.now();

    @Builder.Default
    private Instant updatedAt = Instant.now();
}
